class ZCL_S4H_CLOUD_UTIL definition
  public
  final
  create public .

public section.

  class-methods CLASS_CONSTRUCTOR .
  class-methods GET_SUCCESSORS
    importing
      !TADIR_OBJECT type TROBJTYPE
      !TADIR_OBJ_NAME type SOBJ_NAME
    returning
      value(RESULT) type STRING .
  PROTECTED SECTION.
private section.

  types:
    BEGIN OF ty_entry_flat,
        object_type TYPE trobjtype,
        object_name TYPE sobj_name,
      END OF ty_entry_flat .
  types:
    t_entries_flat TYPE STANDARD TABLE OF ty_entry_flat WITH NON-UNIQUE DEFAULT KEY .
  types:
    ty_successors TYPE STANDARD TABLE OF if_aff_released_check_objs=>ty_successor WITH DEFAULT KEY .

  class-data ERROR_MESSAGE type STRING .
  class-data LT_RELEASED_OBJECTS type T_ENTRIES_FLAT .
  class-data LT_DEPRECATED_OBJECTS type T_ENTRIES_FLAT .
  class-data LT_NOT_TO_BE_REL_OBJECTS type T_ENTRIES_FLAT .
  class-data LT_DEPRECATED_FULL type IF_AFF_RELEASED_CHECK_OBJS=>TY_MAIN-OBJECT_RELEASE_INFO .
  class-data LT_NOT_TO_BE_REL_FULL type IF_AFF_RELEASED_CHECK_OBJS=>TY_MAIN-OBJECT_RELEASE_INFO .
  class-data CLIENT type ref to IF_HTTP_CLIENT .
  class-data LT_CLOUDREPO_FILTERED type table of IF_AFF_RELEASED_CHECK_OBJS=>TY_OBJECT_RELEASE_INFO .

  class-methods ACCESS_URL
    importing
      !URL type SYCM_URL
    exporting
      !E_CLIENT type ref to IF_HTTP_CLIENT .
ENDCLASS.



CLASS ZCL_S4H_CLOUD_UTIL IMPLEMENTATION.


  METHOD access_url.
    CLEAR error_message.

    cl_http_client=>create_by_url(
        EXPORTING
          url                        = CONV #( url )
        IMPORTING
          client                     = e_client
        EXCEPTIONS
          argument_not_found         = 1
          plugin_not_active          = 2
          internal_error             = 3
          pse_not_found              = 4
          pse_not_distrib            = 5
          pse_errors                 = 6
          oa2c_set_token_error       = 7
          oa2c_missing_authorization = 8
          oa2c_invalid_config        = 9
          oa2c_invalid_parameters    = 10
          oa2c_invalid_scope         = 11
          oa2c_invalid_grant         = 12
          OTHERS                     = 13     ).
    IF sy-subrc <> 0.
      IF sy-msgid IS NOT INITIAL.
        MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO error_message.
      ENDIF.

      CLEAR e_client.
      RETURN.
    ENDIF.

    e_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        OTHERS                     = 5     ).
    IF sy-subrc <> 0.
      e_client->get_last_error(
        IMPORTING
          message        =   error_message   ).

      CLEAR e_client.
      RETURN.
    ENDIF.

    e_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4   ).

    IF sy-subrc <> 0.
      e_client->get_last_error(
        IMPORTING
          message   =   error_message   ).

      CLEAR e_client.
      RETURN.
    ENDIF.

    e_client->response->get_status( IMPORTING code = DATA(status_code)  ).

    IF status_code = 200 .
      DATA(content_type) = e_client->response->get_content_type( ).

      IF content_type NP 'text/plain;*'.
        error_message = 'Content from client is not the expected one'(097).
        CLEAR e_client.
        RETURN.
      ENDIF.
    ELSE.
      error_message = | Error: client->response->get_status { status_code } |.
      CLEAR e_client.
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD class_constructor.
* access cloud repo
    DATA l_main                        TYPE if_aff_released_check_objs=>ty_main.
    DATA lt_ars_apis_released_4_c1_scp TYPE if_aff_released_check_objs=>ty_main-object_release_info.
    DATA body                          TYPE xstring.

    CLEAR  error_message.

    IF client IS NOT BOUND.
      access_url(
       EXPORTING
         url      =     " Set default value for released object info URL
 'https://raw.githubusercontent.com/SAP/abap-atc-cr-cv-s4hc/main/src/objectReleaseInfoLatest.json'
        IMPORTING
          e_client      = client ).

      IF client IS BOUND.
        body = client->response->get_data( vscan_scan_always = abap_true ).
      ENDIF.
    ENDIF.

    IF client IS BOUND.
      IF body IS INITIAL.
        body = client->response->get_data( ).
      ENDIF.

      DATA(reader) = cl_sxml_string_reader=>create( body ).

      CALL TRANSFORMATION sycm_xslt_released_check_objs
        SOURCE XML reader
        RESULT root = l_main.

      LOOP AT l_main-object_release_info INTO DATA(ls_main)
        WHERE NOT successors  IS INITIAL .
        APPEND ls_main TO lt_cloudrepo_filtered .
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_successors.
    LOOP AT lt_cloudrepo_filtered ASSIGNING FIELD-SYMBOL(<f_cloudrepo>)
      WHERE object_type EQ tadir_object AND
      object_key EQ tadir_obj_name .
      LOOP AT <f_cloudrepo>-successors ASSIGNING FIELD-SYMBOL(<f_succ>).
        result = SWITCH #( sy-tabix
        WHEN 1 THEN result && <f_succ>-tadir_object && ` ` && <f_succ>-tadir_obj_name
        ELSE result && `; ` && <f_succ>-tadir_object && ` ` && <f_succ>-tadir_obj_name ).
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
