*&---------------------------------------------------------------------*
*& Report  ZTEST_GIT_TABLE_REPLACE_STRING
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*
report ztest_git_table_replace_string.

types: begin of t_tab_chg,
         tabname   type tabname,
         fieldname type fieldname,
         old       type string,
         new       type string,
       end of t_tab_chg.

data gt_tab_chg type standard table of t_tab_chg with default key
      with header line ##NEEDED.

select-options: so_tabnm for gt_tab_chg-tabname.
select-options: so_fldnm for gt_tab_chg-fieldname.

selection-screen: begin of line,
  comment 14(14) text-cas,
  comment 29(20) text-exp,
  end of line.

selection-screen: begin of line,
comment 1(12) text-p01.
selection-screen: position 19.
parameters p_case1  as checkbox.
selection-screen: position 35.
parameters p_regex1 as checkbox.
selection-screen: position 50.
parameters p_condic type string lower case.
selection-screen: end of line.

selection-screen: begin of line,
comment 1(12) text-p02.
selection-screen: position 19.
parameters p_case2  as checkbox.
selection-screen: position 35.
parameters p_regex2 as checkbox.
selection-screen: position 50.
parameters p_source type string lower case.
selection-screen: end of line.


selection-screen: begin of line,
comment 1(12) text-p03.
parameters p_result type string lower case.
selection-screen: end of line.

parameters: p_test as checkbox default 'X'.

start-of-selection.

  perform select_tables.

end-of-selection.

  perform show_alv.

*&---------------------------------------------------------------------*
*&      Form  SHOW_ALV
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
form show_alv .
*Mostrar el resultado en un alv simple
  data: lo_alv type ref to cl_salv_table.
  try.
      cl_salv_table=>factory(
          importing
          r_salv_table = lo_alv
          changing
          t_table      = gt_tab_chg[] ).

      data(lo_functions) = lo_alv->get_functions( ).
      lo_functions->set_all( abap_true ).

      lo_alv->display( ).

    catch cx_salv_msg into data(lx_msg).
      message lx_msg type 'E'.
  endtry.

endform.
*&---------------------------------------------------------------------*
*&      Form  CHECK_TABLE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_L_TABNAME  text
*----------------------------------------------------------------------*
form check_table using p_tabname.
  data l_hay_cambios_linea type abap_bool value abap_false.
  data l_hay_cambios_campo type abap_bool value abap_false.
  data lr_table type ref to data.
  data lr_line type ref to data.
  field-symbols: <lt_contents> type table.
  field-symbols: <lt_contents_upd> type table.
  field-symbols: <lt_contents_del> type table.
  field-symbols: <line_old>.

  data lt_fieldnames type table of fieldname.

  select fieldname into table @lt_fieldnames
    from dd03l
    where tabname eq @p_tabname
      and fieldname in @so_fldnm.

  if lines( lt_fieldnames ) = 0. return. endif.

  create data lr_table type table of (p_tabname).
  assign lr_table->* to <lt_contents>.

  create data lr_table type table of (p_tabname).
  assign lr_table->* to <lt_contents_upd>.

  create data lr_table type table of (p_tabname).
  assign lr_table->* to <lt_contents_del>.


  select * from (p_tabname) into table <lt_contents>.

  loop at <lt_contents> assigning field-symbol(<line>).
    create data lr_line like <line>.
    assign lr_line->* to <line_old>.
    <line_old> = <line>.
    l_hay_cambios_linea = abap_false.
    loop at lt_fieldnames into data(l_fieldname).
      assign component l_fieldname of structure <line>
        to field-symbol(<value>).
      check sy-subrc eq 0.
      perform change_value using p_tabname l_fieldname
                           changing <value> l_hay_cambios_campo.
      if l_hay_cambios_campo eq abap_true.
        l_hay_cambios_linea = abap_true.
      endif.
    endloop.
    if l_hay_cambios_linea eq abap_true.
      append <line> to <lt_contents_upd>.
      append <line_old> to <lt_contents_del>.
    endif.
  endloop.
  if lines( <lt_contents_upd> ) gt 0 and p_test is initial.
    delete (p_tabname) from table <lt_contents_del>.
    if sy-subrc ne 0.
      rollback work.                                   "#EC CI_ROLLBACK
      message e398(00) with  'Tabla' p_tabname 'error al borrar' ##MG_MISSING ##NO_TEXT.
      return.
    endif.
    insert (p_tabname) from table <lt_contents_upd>.
    if sy-subrc ne 0.
      rollback work.                                   "#EC CI_ROLLBACK
      message e398(00) with  'Tabla' p_tabname 'error al insertar' ##MG_MISSING ##NO_TEXT.
      return.
    endif.
    message i398(00) with 'Tabla' p_tabname 'modificada correctamente' ##MG_MISSING ##NO_TEXT.
    commit work.                                       "#EC CI_ROLLBACK
  endif.
endform.

*&---------------------------------------------------------------------*
*&      Form  CHANGE_VALUE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_<VALUE>  text
*----------------------------------------------------------------------*
form change_value using p_tabname p_fieldname
                       changing p_value p_hay_cambios.
  data ls_tab_chg type t_tab_chg.

  p_hay_cambios = abap_false.

  data(lv_contiene) = cond abap_bool(
    " CASO 1: Case Sensitive + Regex
    when p_case1 = abap_true and p_regex1 = abap_true and p_condic is not initial
      and contains( val = p_value regex = p_condic case = abap_true )  then abap_true
    " CASO 2: Case Sensitive + Substring
    when p_case1 = abap_true and p_regex1 = abap_false and p_condic is not initial
      and contains( val = p_value sub = p_condic case = abap_true )   then abap_true
    " CASO 3: Ignore Case + Regex
    when p_case1 = abap_false and p_regex1 = abap_true and p_condic is not initial
      and contains( val = p_value regex = p_condic case = abap_false ) then abap_true
    " CASO 4: Ignore Case + Substring
    when p_case1 = abap_false and p_regex1 = abap_false and p_condic is not initial
      and contains( val = p_value sub = p_condic case = abap_false )  then abap_true
    else abap_false ).

  if lv_contiene = abap_true.
*    if contains( val = <value>-low regex = p_condic case = lv_case_sensitive ).
    ls_tab_chg-tabname = p_tabname.
    ls_tab_chg-fieldname = p_fieldname.
    ls_tab_chg-old = p_value.
    " 2. Si coincide, reemplazamos todas (occ = 0) las ocurrencias de forma directa
    p_value = cond tvarv_val(
    " CASO 1: Case Sensitive + Regex
    when p_case2 = abap_true and p_regex2 = abap_true and p_source is not initial
      then replace( val = p_value regex = p_source with = p_result case = abap_true occ = 0 )
    " CASO 2: Case Sensitive + Substring
    when p_case2 = abap_true and p_regex2 = abap_false and p_source is not initial
      then replace( val = p_value sub = p_source with = p_result case = abap_true  occ = 0 )
    " CASO 3: Ignore Case + Regex
    when p_case2 = abap_false and p_regex2 = abap_true and p_source is not initial
      then replace( val = p_value regex = p_source with = p_result case = abap_false occ = 0 )
    " CASO 4: Ignore Case + Substring
    when p_case2 = abap_false and p_regex2 = abap_false and p_source is not initial
      then replace( val = p_value sub = p_source with = p_result case = abap_false occ = 0 )
    else p_value ).
    ls_tab_chg-new = p_value.
    if ls_tab_chg-new ne ls_tab_chg-old.
      append ls_tab_chg to gt_tab_chg.
      p_hay_cambios = abap_true.
    endif.
  endif.
endform.
*&---------------------------------------------------------------------*
*&      Form  SELECT_TABLES
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
form select_tables .
  select tabname
    from dd02l
    into table @data(lt_tabname)
    where tabname in @so_tabnm
      and tabclass = 'TRANSP'.    " Asegura que sean tablas transparentes

  loop at lt_tabname into data(l_tabname).
    perform check_table using l_tabname.
  endloop.
endform.
