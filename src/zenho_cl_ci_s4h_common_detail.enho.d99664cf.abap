"Name: \TY:CL_CI_S4H_COMMON\ME:GET_DETAIL_FROM_DATA_BUFFER\SE:END\EI
ENHANCEMENT 0 ZENHO_CL_CI_S4H_COMMON_DETAIL.
DATA: lv_obj_type TYPE tadir-object,
      lv_obj_name TYPE tadir-obj_name.
CLEAR: lv_obj_type, lv_obj_name .
IF ld_ref_obj_type->* IS NOT INITIAL.
  lv_obj_type =   ld_ref_obj_type->* .
ENDIF.

IF ld_ref_obj_name->* IS NOT INITIAL.
  lv_obj_name =   ld_ref_obj_name->*  .
ENDIF.

DATA(ls_info_succ) = zcl_s4h_cloud_util=>get_successors( tadir_object = lv_obj_type tadir_obj_name =  lv_obj_name ) .
IF NOT ls_info_succ IS INITIAL.
  ls_info_succ = 'Replace by:' && ls_info_succ  .
  CONDENSE ls_info_succ.
  IF ld_additional_info->* IS NOT INITIAL.
    ls_detail = et_detail[ name = 'ADD_INFO' ] .
    ls_detail-value->* = ls_info_succ && ls_detail-value->* .
  ELSE.
    ld_additional_info->* = ls_info_succ .
    Ls_DETAIL-name  = 'ADD_INFO'.                  " Has to be upper case
    Ls_DETAIL-value = ld_additional_info.
    INSERT Ls_DETAIL INTO TABLE et_DETAIL.
  ENDIF.
ENDIF.

ENDENHANCEMENT.
