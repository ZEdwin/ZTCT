REPORT zev_tp_checktool.
*--------------------------------------------------------------------*
*  Report   : ZEV_TP_CHECKTOOL                                       *
*--------------------------------------------------------------------*
*  Copyright (c) 2012, E.Vleeshouwers                                *
*--------------------------------------------------------------------*
*  Program Details                                                   *
*--------------------------------------------------------------------*
*  Title    : Transport checking tool (on object level)              *
*  Purpose  : Check transport objects before moving to production    *
*--------------------------------------------------------------------*
*  SOURCE: https://github.com/ZEdwin/ZTCT                            *
*  BLOG (SCN):                                                       *
*  http://scn.sap.com/community/abap/blog/2013/05/31/transport-      *
*  checking-tool-object-level                                        *
*--------------------------------------------------------------------*
*  INSTALLATION                                                      *
*--------------------------------------------------------------------*
*  Use of ABAPGIT is recommended. SAPLINK is no longer maintained    *
*--------------------------------------------------------------------*
* Class for handling Events
CLASS lcl_eventhandler_ztct DEFINITION DEFERRED.
CLASS lcl_ztct              DEFINITION DEFERRED.

* CTS: Header
DATA e070       TYPE e070.
* CTS: Object Entries Requests/Task
DATA e071       TYPE e071.
* Assignm. of CTS Proj. to Ext. Proj.
DATA ctsproject TYPE ctsproject.

*--------------------------------------------------------------------*
* Data definitions
*--------------------------------------------------------------------*
* Fields on selection screens
TABLES sscrfields.

CONSTANTS co_langu          TYPE ddlanguage VALUE 'E'.

DATA lt_range_project_trkorrs TYPE RANGE OF ctsproject-trkorr ##NEEDED.
DATA ls_range_project_trkorrs LIKE LINE  OF lt_range_project_trkorrs ##NEEDED.
DATA ra_systems             TYPE RANGE OF tmscsys-sysnam ##NEEDED.
DATA ls_systems             LIKE LINE  OF ra_systems ##NEEDED.

* Global data declarations:
DATA tp_prefix              TYPE char5 ##NEEDED.
DATA st_tcesyst             TYPE tcesyst ##NEEDED.
DATA st_smp_dyntxt          TYPE smp_dyntxt ##NEEDED.
* To check existence of documentation
DATA tp_dokl_object         TYPE doku_obj ##NEEDED.

DATA ta_trkorr_range        TYPE RANGE OF e070-trkorr ##NEEDED.
DATA st_trkorr_range        LIKE LINE OF ta_trkorr_range ##NEEDED.
DATA ta_project_range       TYPE RANGE OF ctsproject-trkorr ##NEEDED.
DATA lt_excluded_objects    TYPE RANGE OF trobj_name ##NEEDED.
DATA ta_transport_descr     TYPE STANDARD TABLE OF as4text ##NEEDED.
DATA tp_transport_descr     TYPE as4text ##NEEDED.
DATA tp_descr_exists        TYPE abap_bool ##NEEDED.
DATA tp_tabix               TYPE sytabix ##NEEDED.
DATA tp_project_reference   TYPE trvalue ##NEEDED.
* Process type is used to identify if a list is build (1),
* uploaded (2) or the program is used for version checking (3)
DATA tp_process_type        TYPE i ##NEEDED.
DATA ta_targets             TYPE trsysclis ##NEEDED.
DATA st_target              TYPE trsyscli ##NEEDED.
DATA tp_sysname             TYPE sysname ##NEEDED.
DATA tp_msg                 TYPE string ##NEEDED.

*--------------------------------------------------------------------*
* Data - ALV
*--------------------------------------------------------------------*
* Declaration for ALV Grid
DATA rf_table                TYPE REF TO cl_salv_table ##NEEDED.
DATA rf_table_xls            TYPE REF TO cl_salv_table ##NEEDED.
DATA rf_conflicts            TYPE REF TO cl_salv_table ##NEEDED.
DATA rf_table_keys           TYPE REF TO cl_salv_table ##NEEDED.
DATA rf_handle_events        TYPE REF TO lcl_eventhandler_ztct ##NEEDED.
DATA rf_events_table         TYPE REF TO cl_salv_events_table ##NEEDED.

* Exception handling
DATA rf_root                 TYPE REF TO cx_root ##NEEDED.
DATA rf_ztct                 TYPE REF TO lcl_ztct ##NEEDED.

*----------------------------------------------------------------------*
*       CLASS lcl_eventhandler_ztct DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_eventhandler_ztct DEFINITION FINAL FRIENDS lcl_ztct.

  PUBLIC SECTION.

    CLASS-METHODS on_function_click
      FOR EVENT if_salv_events_functions~added_function
        OF cl_salv_events_table IMPORTING e_salv_function.

    CLASS-METHODS on_double_click
      FOR EVENT double_click
        OF cl_salv_events_table IMPORTING row column.

    CLASS-METHODS on_link_click
      FOR EVENT link_click
        OF cl_salv_events_table IMPORTING row column.

    CLASS-METHODS on_double_click_popup
      FOR EVENT double_click
        OF cl_salv_events_table IMPORTING row column.

    CLASS-METHODS on_link_click_popup
      FOR EVENT link_click
        OF cl_salv_events_table IMPORTING row column.

  PRIVATE SECTION.
    CLASS-DATA:
      rf_conflicts  TYPE REF TO cl_salv_table,
      rf_table_keys TYPE REF TO cl_salv_table.

ENDCLASS.

*----------------------------------------------------------------------*
*       CLASS lcl_ztct DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_ztct DEFINITION FINAL FRIENDS lcl_eventhandler_ztct.

  PUBLIC SECTION.

    TYPES ty_range_trkorr           TYPE RANGE OF trkorr.
    TYPES ty_range_excluded_objects TYPE RANGE OF trobj_name.
    TYPES: BEGIN OF ty_request_details,
             trkorr         TYPE trkorr,
             checked        TYPE icon_l4,
             info           TYPE icon_l4,
             tr_descr       TYPE as4text,
             dev            TYPE icon_l4,
             qas            TYPE icon_l4,
             retcode        TYPE char04,
             prd            TYPE icon_l4,
             warning_lvl    TYPE icon_d,
*            Warning_rank: The higher the number,
*            the more serious the error
             warning_rank   TYPE numc4,
             warning_txt    TYPE text74,
             pgmid          TYPE pgmid,
             object         TYPE trobjtype,
             obj_name       TYPE trobj_name,
             objkey         TYPE trobj_name,
             keyobject      TYPE trobjtype,
             keyobjname     TYPE tabname,
             tabkey         TYPE tabkey,
             checked_by     TYPE syuname,
             as4date        TYPE as4date,
             as4time        TYPE as4time,
             as4user        TYPE as4user,
             status_text    TYPE char20,
             trfunction_txt TYPE val_text,
             project        TYPE cts_id,
             project_descr  TYPE as4text,
             objfunc        TYPE objfunc,
             flag           TYPE flag,
             trstatus       TYPE trstatus,
             trfunction     TYPE trfunction,
             re_import      TYPE char20.
    TYPES:   t_color TYPE lvc_t_scol,
             END OF ty_request_details.

    TYPES ty_request_details_tt TYPE STANDARD TABLE OF ty_request_details
                                WITH KEY trkorr obj_name.

    TYPES: BEGIN OF ty_tables_with_keys,
             tabname TYPE trobj_name,
             ddtext  TYPE as4text,
             counter TYPE i,
           END OF ty_tables_with_keys.

*   Methods
    METHODS constructor.
    METHODS execute.
    METHODS refresh_alv.
    METHODS docu_call                   IMPORTING im_object     TYPE doku_obj
                                                  im_id         TYPE dokhl-id
                                                  im_display    TYPE abap_bool OPTIONAL
                                                  im_displ_mode TYPE c OPTIONAL.
    METHODS get_tp_prefix               IMPORTING im_dev              TYPE sysname OPTIONAL
                                        RETURNING VALUE(re_tp_prefix) TYPE char5.
    METHODS get_filename                RETURNING VALUE(re_file) TYPE string.
    METHODS set_check_flag              IMPORTING im_check_flag TYPE abap_bool OPTIONAL.
    METHODS set_check_tabkeys           IMPORTING im_check_tabkeys TYPE abap_bool OPTIONAL.
    METHODS set_clear_checked           IMPORTING im_clear_checked TYPE abap_bool OPTIONAL.
    METHODS set_buffer_chk              IMPORTING im_buffer_chk TYPE abap_bool OPTIONAL.
    METHODS set_buffer_remove_tp        IMPORTING im_buffer_remove_tp TYPE abap_bool OPTIONAL.
    METHODS set_trkorr_range            IMPORTING im_trkorr_range TYPE ty_range_trkorr OPTIONAL.
    METHODS set_project_range           IMPORTING im_project_range TYPE ty_range_trkorr OPTIONAL.
    METHODS set_excluded_objects        IMPORTING im_excluded_objects TYPE ty_range_excluded_objects OPTIONAL.
    METHODS set_user_layout             IMPORTING im_user_layout TYPE abap_bool OPTIONAL.
    METHODS set_process_type            IMPORTING im_process_type TYPE i.
    METHODS set_skiplive                IMPORTING im_skiplive TYPE abap_bool OPTIONAL.
    METHODS set_filename                IMPORTING im_filename TYPE string OPTIONAL.
    METHODS set_systems                 IMPORTING im_dev_system TYPE sysname
                                                  im_qas_system TYPE sysname
                                                  im_prd_system TYPE sysname.
    METHODS set_building_conflict_popup IMPORTING im_building_conflict_popup TYPE abap_bool OPTIONAL.
    METHODS go_back_months              IMPORTING im_backmonths  TYPE numc3
                                                  im_currdate    TYPE sydatum
                                        RETURNING VALUE(re_date) TYPE sydatum.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_tms_mgr_buffer,
             request       TYPE  tmsbuffer-trkorr,
             target_system TYPE  tmscsys-sysnam,
             request_infos TYPE  stms_wbo_requests,
           END   OF ty_tms_mgr_buffer.
    TYPES ty_tms_mgr_buffer_tt TYPE HASHED TABLE OF ty_tms_mgr_buffer
                               WITH UNIQUE KEY request target_system.

    DATA tms_mgr_buffer      TYPE ty_tms_mgr_buffer_tt.
    DATA tms_mgr_buffer_line TYPE ty_tms_mgr_buffer.

    TYPES: BEGIN OF ty_ddic_e071,
             trkorr   TYPE trkorr,
             pgmid    TYPE pgmid,
             object   TYPE trobjtype,
             obj_name TYPE trobj_name,
           END OF ty_ddic_e071.
    TYPES ty_ddic_e071_tt           TYPE STANDARD TABLE OF ty_ddic_e071.

    DATA ls_excluded_objects        LIKE LINE OF lt_excluded_objects.
    DATA table_keys                 TYPE TABLE OF ty_tables_with_keys.
    DATA table_keys_line            TYPE ty_tables_with_keys.
*   Attributes
    DATA main_list                  TYPE ty_request_details_tt.
    DATA main_list_line             TYPE ty_request_details.
    DATA main_list_xls              TYPE ty_request_details_tt.
    DATA main_list_line_xls         TYPE ty_request_details.
    DATA conflicts                  TYPE ty_request_details_tt.
    DATA st_request                 TYPE ctslg_request_info.
    DATA st_steps                   TYPE ctslg_step.
    DATA st_actions                 TYPE ctslg_action.
    DATA tp_tabkey                  TYPE trobj_name.
    DATA tp_tab                     TYPE char1
                                    VALUE cl_abap_char_utilities=>horizontal_tab.
    DATA lp_save_restriction        TYPE salv_de_layout_restriction.
    CONSTANTS:
*     ICON_INFORMATION
      co_info    TYPE icon_d         VALUE '@AH@',
*     ICON_LED_RED
      co_error   TYPE icon_d         VALUE '@F1@',
*     ICON_SYSTEM_CANCEL
      co_tp_fail TYPE icon_d         VALUE '@2O@',
*     ICON_INCOMPLETE
      co_ddic    TYPE icon_d         VALUE '@CY@',
*     ICON_LED_YELLOW
      co_warn    TYPE icon_d         VALUE '@5D@',
*     ICON_LED_GREEN
      co_okay    TYPE icon_d         VALUE '@5B@',
*     ICON_CHECKED
      co_checked TYPE icon_d         VALUE '@01@',
*     ICON_HINT
      co_hint    TYPE icon_d         VALUE '@AI@',
*     ICON_FAILURE
      co_alert   TYPE icon_d         VALUE '@03@',
*     ICON_SCRAP
      co_scrap   TYPE icon_d         VALUE '@K3@',
*     ICON_PROTOCOL
      co_docu    TYPE icon_d         VALUE '@DH@',
*     ICON_LED_INACTIVE
      co_inact   TYPE icon_d         VALUE '@BZ@'.
    CONSTANTS:
*     ICON_FAILURE
      co_alert0_rank  TYPE i         VALUE 25,
*     ICON_FAILURE
      co_alert1_rank  TYPE i         VALUE 26,
*     ICON_FAILURE
      co_alert2_rank  TYPE i         VALUE 27,
*     ICON_FAILURE
      co_alert3_rank  TYPE i         VALUE 28,
*     ICON_HINT
      co_hint2_rank   TYPE i         VALUE 12,
*     ICON_HINT
      co_hint3_rank   TYPE i         VALUE 14,
*     ICON_INFORMATION
      co_info_rank    TYPE i         VALUE 20,
*     ICON_LED_YELLOW
      co_warn_rank    TYPE i         VALUE 50,
*     ICON_SYSTEM_CANCEL
      co_tp_fail_rank TYPE i         VALUE 97,
*     ICON_INCOMPLETE
      co_ddic_rank    TYPE i         VALUE 98,
*     ICON_LED_RED
      co_error_rank   TYPE i         VALUE 99.
    CONSTANTS co_non_charlike        TYPE string VALUE 'h'.

    DATA lp_alert0_text              TYPE text74.
    DATA lp_alert1_text              TYPE text74.
    DATA lp_alert2_text              TYPE text74.
    DATA lp_alert3_text              TYPE text74.
    DATA lp_hint1_text               TYPE text74.
    DATA lp_hint2_text               TYPE text74.
    DATA lp_hint3_text               TYPE text74.
    DATA lp_hint4_text               TYPE text74.
    DATA lp_info_text                TYPE text74.
    DATA lp_fail_text                TYPE text74.
    DATA lp_warn_text                TYPE text74.
    DATA lp_error_text               TYPE text74.
    DATA lp_ddic_text                TYPE text74.

* Attributes
    DATA project_trkorrs             TYPE ty_range_trkorr.
    DATA prefix                      TYPE char5.
    DATA aggr_tp_list_of_objects     TYPE ty_request_details_tt.
    DATA add_to_main                 TYPE ty_request_details_tt.
    DATA tab_delimited               TYPE table_of_strings.
    DATA conflict_line               TYPE ty_request_details.
    DATA line_found_in_list          TYPE ty_request_details.
    DATA total                       TYPE sytabix.
    DATA ddic_objects                TYPE string_table.
    DATA ddic_objects_sub            TYPE string_table.
    DATA ddic_e071                   TYPE ty_ddic_e071_tt.
    DATA ddic_e071_line              TYPE ty_ddic_e071.
    DATA where_used                  TYPE sci_findlst.
    DATA where_used_line             TYPE rsfindlst.
    DATA check_flag                  TYPE abap_bool.
    DATA check_ddic                  TYPE abap_bool.
    DATA check_tabkeys               TYPE abap_bool.
    DATA clear_checked               TYPE abap_bool.
    DATA buffer_chk                  TYPE abap_bool.
    DATA buffer_remove_tp            TYPE abap_bool.
    DATA trkorr_range                TYPE ty_range_trkorr.
    DATA project_range               TYPE ty_range_trkorr.
    DATA excluded_objects            TYPE ty_range_excluded_objects.
    DATA user_layout                 TYPE abap_bool.
    DATA process_type                TYPE i.
    DATA skiplive                    TYPE abap_bool.
    DATA filename                    TYPE string.
    DATA dev_system                  TYPE sysname.
    DATA qas_system                  TYPE sysname.
    DATA prd_system                  TYPE sysname.
    DATA systems_range               TYPE RANGE OF tmscsys-sysnam.
    DATA building_conflict_popup     TYPE flag.

    METHODS refresh_import_queues.
    METHODS handle_error             IMPORTING im_oref TYPE REF TO cx_root.
    METHODS flag_for_process         IMPORTING im_rows TYPE salv_t_row
                                               im_cell TYPE salv_s_cell.
    METHODS get_main_transports      IMPORTING im_trkorr_range TYPE gtabkey_trkorrt.
    METHODS get_tp_info              IMPORTING im_trkorr      TYPE trkorr
                                               im_obj_name    TYPE trobj_name
                                     RETURNING VALUE(re_line) TYPE ty_request_details.
    METHODS get_added_objects        IMPORTING im_to_add        TYPE ty_range_trkorr
                                     RETURNING VALUE(re_to_add) TYPE ty_request_details_tt.
    METHODS add_to_list              IMPORTING im_list        TYPE ty_request_details_tt
                                               im_to_add      TYPE ty_request_details_tt
                                     RETURNING VALUE(re_main) TYPE ty_request_details_tt.
    METHODS build_conflict_popup     IMPORTING im_rows TYPE salv_t_row
                                               im_cell TYPE salv_s_cell.
    METHODS delete_tp_from_list      IMPORTING im_rows TYPE salv_t_row.
    METHODS flag_same_objects        CHANGING  ch_main_list TYPE ty_request_details_tt.
    METHODS mark_all_tp_records      IMPORTING im_cell TYPE salv_s_cell
                                     CHANGING  ch_rows TYPE salv_t_row.
    METHODS main_to_tab_delimited    IMPORTING im_main_list            TYPE ty_request_details_tt
                                     RETURNING VALUE(re_tab_delimited) TYPE table_of_strings.
    METHODS tab_delimited_to_main    IMPORTING im_tab_delimited TYPE table_of_strings.
    METHODS display_transport        IMPORTING im_trkorr TYPE trkorr.
    METHODS display_user             IMPORTING im_user TYPE syuname.
    METHODS display_docu             IMPORTING im_trkorr TYPE trkorr.
    METHODS check_if_in_list         IMPORTING im_line        TYPE ty_request_details
                                               im_tabix       TYPE sytabix
                                     RETURNING VALUE(re_line) TYPE ty_request_details.
    METHODS check_documentation      IMPORTING im_trkorr TYPE trkorr
                                     CHANGING  ch_table  TYPE ty_request_details_tt.
    METHODS clear_flags.
    METHODS column_settings          IMPORTING im_column_ref       TYPE salv_t_column_ref
                                               im_rf_columns_table TYPE REF TO cl_salv_columns_table
                                               im_table            TYPE REF TO cl_salv_table.
    METHODS is_empty_column          IMPORTING im_column          TYPE lvc_fname
                                               im_table           TYPE ty_request_details_tt
                                     RETURNING VALUE(re_is_empty) TYPE abap_bool.
    METHODS display_excel            IMPORTING im_table TYPE ty_request_details_tt.
    METHODS set_tp_prefix            IMPORTING im_dev TYPE sysname OPTIONAL.
    METHODS top_of_page              RETURNING VALUE(re_form_element) TYPE REF TO cl_salv_form_element.
    METHODS check_newer_transports   IMPORTING im_newer_transports TYPE ty_request_details_tt
                                               im_main_list        TYPE ty_request_details_tt
                                     CHANGING  ch_conflicts        TYPE ty_request_details_tt
                                               ch_main             TYPE ty_request_details.
    METHODS check_older_transports   IMPORTING im_older_transports TYPE ty_request_details_tt
                                               im_main_list        TYPE ty_request_details_tt
                                     CHANGING  ch_conflicts        TYPE ty_request_details_tt
                                               ch_main             TYPE ty_request_details.
    METHODS check_if_same_object     IMPORTING im_line        TYPE ty_request_details
                                               im_newer_older TYPE ty_request_details
                                     EXPORTING ex_tabkey      TYPE trobj_name
                                               ex_return      TYPE c.
    METHODS sort_list                CHANGING  ch_list        TYPE ty_request_details_tt.
    METHODS determine_warning_text   IMPORTING im_highest_rank        TYPE numc4
                                     RETURNING VALUE(re_highest_text) TYPE text74.
    METHODS get_tps_for_same_object  IMPORTING im_line  TYPE ty_request_details
                                     EXPORTING ex_newer TYPE ty_request_details_tt
                                               ex_older TYPE ty_request_details_tt.
    METHODS progress_indicator       IMPORTING im_counter TYPE sytabix
                                               im_object  TYPE trobj_name
                                               im_total   TYPE sytabix
                                               im_text    TYPE itex132
                                               im_flag    TYPE c.
    METHODS alv_xls_init             EXPORTING ex_rf_table TYPE REF TO cl_salv_table
                                     CHANGING  ch_table    TYPE STANDARD TABLE.
    METHODS alv_xls_output.
    METHODS prepare_ddic_check.
    METHODS set_ddic_objects.
    METHODS do_ddic_check            CHANGING  ch_main_list TYPE ty_request_details_tt.
    METHODS set_properties_conflicts IMPORTING im_table       TYPE ty_request_details_tt
                                     RETURNING VALUE(re_xend) TYPE i.
    METHODS get_data                 IMPORTING im_trkorr_range TYPE gtabkey_trkorrt.
    METHODS check_for_conflicts      CHANGING  ch_main_list TYPE ty_request_details_tt.
    METHODS build_table_keys_popup.
    METHODS add_table_keys_to_list   CHANGING  ch_table TYPE ty_request_details_tt.
    METHODS get_additional_tp_info   CHANGING  ch_table TYPE ty_request_details_tt.
    METHODS gui_upload               IMPORTING im_filename         TYPE string
                                     RETURNING VALUE(re_cancelled) TYPE abap_bool.
    METHODS determine_col_width      IMPORTING im_field    TYPE any
                                     CHANGING  ch_colwidth TYPE lvc_outlen.
    METHODS check_colwidth           IMPORTING im_name            TYPE abap_compname
                                               im_colwidth        TYPE lvc_outlen
                                     RETURNING VALUE(re_colwidth) TYPE lvc_outlen.
    METHODS remove_tp_in_prd.
    METHODS alv_init.
    METHODS set_color.
    METHODS alv_set_properties       IMPORTING im_table TYPE REF TO cl_salv_table.
    METHODS alv_set_lr_tooltips      IMPORTING im_table TYPE REF TO cl_salv_table.
    METHODS alv_output.
    METHODS set_where_used.
    METHODS get_import_datetime_qas  IMPORTING im_trkorr  TYPE trkorr
                                     EXPORTING ex_as4time TYPE as4time
                                               ex_as4date TYPE as4date
                                               ex_return  TYPE sysubrc.
    METHODS exclude_all_tables.
    METHODS ofc_goon                 IMPORTING im_rows  TYPE salv_t_row
                                     CHANGING  ch_table TYPE REF TO cl_salv_table.
    METHODS ofc_abr                  CHANGING  ch_conflicts TYPE REF TO cl_salv_table.
    METHODS ofc_ddic.
    METHODS ofc_add_tp.
    METHODS ofc_save.
    METHODS ofc_nconf                IMPORTING im_selections TYPE REF TO cl_salv_selections
                                     CHANGING  ch_cell       TYPE salv_s_cell.
    METHODS get_additional_info      IMPORTING im_indexinc       TYPE sytabix
                                     CHANGING  ch_main_list_line TYPE ty_request_details
                                               ch_table          TYPE ty_request_details_tt.
ENDCLASS.

*--------------------------------------------------------------------*
* Selection screen Build
*--------------------------------------------------------------------*

* Possibility to add a button on the selection screen application
* toolbar (If required, uncomment). Function text and icon is filled
* in AT SELECTION-SCREEN OUTPUT
SELECTION-SCREEN: FUNCTION KEY 1.

* B10: Selection range / Upload file
*---------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK box1 WITH FRAME TITLE sc_b10.
PARAMETERS p_sel RADIOBUTTON GROUP mod DEFAULT 'X'
                                       USER-COMMAND sel.
PARAMETERS p_upl RADIOBUTTON GROUP mod.
SELECTION-SCREEN END OF BLOCK box1.

* B20: Selection criteria or Upload file
*---------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK box2 WITH FRAME TITLE sc_b20.
SELECT-OPTIONS s_korr FOR e070-strkorr MODIF ID sel.
PARAMETERS p_str TYPE as4text VISIBLE LENGTH 41
                              MODIF ID sel.
SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(20) sc_c21 MODIF ID sel.
SELECTION-SCREEN POSITION 30.
SELECT-OPTIONS s_user FOR sy-uname DEFAULT sy-uname
                                   MATCHCODE OBJECT user_addr
                                   MODIF ID sel.
SELECTION-SCREEN PUSHBUTTON 71(5) sc_name
                                  USER-COMMAND name
                                  MODIF ID sel.             "#EC NEEDED
SELECTION-SCREEN END OF LINE.
SELECT-OPTIONS s_date FOR e070-as4date MODIF ID sel.
SELECTION-SCREEN PUSHBUTTON 69(7) sc_date
                                  USER-COMMAND date
                                  MODIF ID sel.             "#EC NEEDED
SELECT-OPTIONS s_proj FOR ctsproject-trkorr MODIF ID sel.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(20) sc_c22 MODIF ID upl.
SELECTION-SCREEN POSITION POS_LOW.
PARAMETERS p_file TYPE string MODIF ID upl.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK box2.

* B30: Transport Track
*---------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK box3 WITH FRAME TITLE sc_b30.
SELECTION-SCREEN BEGIN OF LINE.
* C31 - Route
SELECTION-SCREEN COMMENT 1(20) sc_c31.
SELECTION-SCREEN POSITION POS_LOW.
PARAMETERS p_dev TYPE sysname DEFAULT 'DEV' ##SEL_WRONG.
* C32 - -->
SELECTION-SCREEN COMMENT 45(3) sc_c32.
SELECTION-SCREEN POSITION 51.
PARAMETERS p_qas TYPE sysname DEFAULT 'QAS'.
* C33 - -->
SELECTION-SCREEN COMMENT 63(3) sc_c33.
SELECTION-SCREEN POSITION 69.
PARAMETERS p_prd TYPE sysname DEFAULT 'PRD'.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK box3.

* B40: Check options
*---------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK box4 WITH FRAME TITLE sc_b40.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_noprd AS CHECKBOX DEFAULT 'X' ##SEL_WRONG.
* C40 - Do not select transports already in production
SELECTION-SCREEN COMMENT 4(63) sc_c40.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_user AS CHECKBOX DEFAULT ' '.
* C41 - Use User specific layout
SELECTION-SCREEN COMMENT 4(63) sc_c41.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_buff AS CHECKBOX DEFAULT 'X' USER-COMMAND buf ##SEL_WRONG.
* C42 - Check transport buffer
SELECTION-SCREEN COMMENT 4(22) sc_c42.
PARAMETERS p_buffd AS CHECKBOX DEFAULT 'X' MODIF ID buf ##SEL_WRONG.
SELECTION-SCREEN COMMENT 29(35) sc_c45 MODIF ID buf.
SELECTION-SCREEN PUSHBUTTON (4) sc_buff
                                USER-COMMAND buff
                                MODIF ID buf
                                VISIBLE LENGTH 2.           "#EC NEEDED
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_chkky AS CHECKBOX DEFAULT 'X' MODIF ID chk
                   USER-COMMAND key.
* C43 - Check table keys
SELECTION-SCREEN COMMENT 4(16) sc_c43    MODIF ID chk.
SELECTION-SCREEN PUSHBUTTON 65(4) sc_ckey
                                  USER-COMMAND ckey
                                  MODIF ID chk
                                  VISIBLE LENGTH 2.         "#EC NEEDED
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_chd AS CHECKBOX DEFAULT ' ' MODIF ID upl.
* C44  - Reset 'Checked' field
SELECTION-SCREEN COMMENT 4(16) sc_c44 MODIF ID upl.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK box4.

* B50: Exclude from check
*---------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK box5 WITH FRAME TITLE sc_b50.
*C51 - Objects in the range will not be taken into account when checking
*      the
SELECTION-SCREEN COMMENT /1(74) sc_c51 MODIF ID chk.
*C52 - transports. Useful to exclude common customizing tables (like
*      SWOTICE for
SELECTION-SCREEN COMMENT /1(74) sc_c52 MODIF ID chk.
* C53 - workflow or the tables for Pricing procedures).
SELECTION-SCREEN COMMENT /1(74) sc_c53 MODIF ID chk.
SELECT-OPTIONS s_exobj FOR e071-obj_name NO INTERVALS
                                         MODIF ID chk.
SELECTION-SCREEN END OF BLOCK box5.

*--------------------------------------------------------------------*
* Initialize
*--------------------------------------------------------------------*
INITIALIZATION.

* To be able to use methods on the selection screen
  IF rf_ztct IS NOT BOUND.
    TRY.
        rf_ztct = NEW #( ).
      CATCH cx_root INTO rf_root ##CATCH_ALL.
        tp_msg = rf_root->get_text( ).
        CONCATENATE 'ERROR:'(038) tp_msg INTO tp_msg SEPARATED BY space.
        MESSAGE tp_msg TYPE 'E'.
    ENDTRY.
  ENDIF.
* icon_terminated_position.
  sc_name = '@L8@'.
  sc_date = 'Clear'(025).
  IF s_date IS INITIAL.
    sc_date = 'Clear'(025).
    s_date-sign = 'I'.
    s_date-option = 'BT'.
    s_date-high = sy-datum.
    s_date-low = rf_ztct->go_back_months( im_currdate   = sy-datum
                                          im_backmonths = 6 ).
    APPEND s_date TO s_date.
  ELSE.
    sc_date = 'Def.'(026).
    FREE s_date.
  ENDIF.

* Set selection texts (to link texts to selection screen):
* This is done to facilitate (love that word...) the copying of this
* program to other environments without losing all the texts.
  sc_b10 = 'Selection range / Upload file'(b10).
  sc_b30 = 'Transport Track'(b30).
  sc_b40 = 'Check options'(b40).
  sc_b50 = 'Exclude from check'(b50).
  sc_c21 = 'User'(c21).
  sc_c22 = 'File name'(c22).
  sc_c31 = 'Route'(c31).
  sc_c32 = '-->'(c32).
  sc_c33 = sc_c32.
  sc_c40 = 'Do not select transports already in production'(c40).
  sc_c41 = 'Use User specific layout'(c41).
  sc_c42 = 'Check transport buffer'(c42).
  sc_c43 = 'Check table keys'(c43).
  sc_c44 = 'Reset `Checked` field'(c44).
  sc_c45 = 'Remove transports not in buffer'(c45).
  sc_c51 = 'Objects in the range will not be taken into account when checking the'(c51).
  sc_c52 = 'transports. Useful to exclude common customizing tables (like SWOTICE for'(c52).
  sc_c53 = 'workflow or the tables for Pricing procedures).'(c53).

  WRITE icon_information AS ICON TO sc_buff.
  WRITE icon_information AS ICON TO sc_ckey.

* Create a range table containing all project numbers:
  SELECT 'E' AS sign,
         'EQ' AS option,
         trkorr AS low
         FROM ctsproject
         INTO CORRESPONDING FIELDS OF TABLE @lt_range_project_trkorrs
         ORDER BY low.                   "#EC CI_SGLSELECT #EC CI_SUBRC

* Get the transport track
  tp_sysname = sy-sysid.
  CALL FUNCTION 'TR_GET_LIST_OF_TARGETS'
    EXPORTING
      iv_src_system    = tp_sysname
    IMPORTING
      et_targets       = ta_targets
    EXCEPTIONS
      tce_config_error = 1
      OTHERS           = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
  p_dev = sy-sysid.
  LOOP AT ta_targets INTO st_target.
    CASE sy-tabix.
      WHEN 1.
        p_qas = st_target.
      WHEN 2.
        p_prd = st_target.
    ENDCASE.
  ENDLOOP.

* Default values for s_exobj. These objects will not be checked!
* Exclude Single values:
  s_exobj-sign   = 'E'.
  s_exobj-option = 'EQ'.
* Index of Frozen DDIC Structures
  s_exobj-low    = 'SWOTICE'.
  APPEND s_exobj TO s_exobj.
* View Directory
  s_exobj-low    = 'TVDIR'.
  APPEND s_exobj TO s_exobj.
* Maintenance Areas for Tables
  s_exobj-low    = 'TDDAT'.
  APPEND s_exobj TO s_exobj.
*--------------------------------------------------------------------*
* Selection screen Checks
*--------------------------------------------------------------------*
AT SELECTION-SCREEN.
  CASE sy-ucomm.
    WHEN 'FC01'.
      tp_dokl_object = 'ZEV_TP_CHECKTOOL'.
      rf_ztct->docu_call( im_object     = tp_dokl_object
                          im_id         = 'TX'
                          im_display    = abap_true
                          im_displ_mode = '2' ).
    WHEN 'BUFF'.
      tp_dokl_object = 'ZEV_TP_CHECKTOOL_BUFF'.
      rf_ztct->docu_call( im_object     = tp_dokl_object
                          im_id         = 'TX'
                          im_display    = abap_true
                          im_displ_mode = '2' ).
    WHEN 'CKEY'.
      tp_dokl_object = 'ZEV_TP_CHECKTOOL_CKEY'.
      rf_ztct->docu_call( im_object     = tp_dokl_object
                          im_id         = 'TX'
                          im_display    = abap_true
                          im_displ_mode = '2' ).
    WHEN 'NAME'.
      IF s_user IS NOT INITIAL.
        FREE s_user.
        CLEAR s_user.
        sc_name = '@LD@'.
      ELSE.
        s_user-option = 'EQ'.
        s_user-sign = 'I'.
        s_user-low = sy-uname.
        APPEND s_user TO s_user.
        sc_name = '@L8@'.
      ENDIF.
    WHEN 'DATE'.
      IF s_date IS INITIAL.
        sc_date = 'Clear'(025).
        IF s_date[] IS INITIAL.
          s_date-sign = 'I'.
          s_date-option = 'BT'.
          s_date-high = sy-datum.
          s_date-low = rf_ztct->go_back_months( im_currdate   = sy-datum
                                                im_backmonths = 6 ).
          APPEND s_date TO s_date.
        ENDIF.
      ELSE.
        sc_date = 'Def.'(026).
        FREE s_date.
      ENDIF.
  ENDCASE.

AT SELECTION-SCREEN ON p_dev.
  SELECT SINGLE sysname FROM tcesyst INTO @tp_sysname
                        WHERE sysname = @p_dev ##WARN_OK.
  IF sy-subrc <> 0.
    MESSAGE e000(db) DISPLAY LIKE 'E'
                     WITH 'System'(057) p_dev 'does not exist...'(058).
  ENDIF.

AT SELECTION-SCREEN ON p_qas.
  SELECT SINGLE sysname FROM tcesyst INTO @tp_sysname
                        WHERE sysname = @p_qas ##WARN_OK.
  IF sy-subrc <> 0.
    MESSAGE e000(db) DISPLAY LIKE 'E'
                     WITH 'System'(057) p_qas 'does not exist...'(058).
  ENDIF.

AT SELECTION-SCREEN ON p_prd.
  SELECT SINGLE sysname FROM tcesyst INTO @tp_sysname
                        WHERE sysname = @p_prd ##WARN_OK.
  IF sy-subrc <> 0.
    MESSAGE e000(db) DISPLAY LIKE 'E'
                     WITH 'System'(057) p_prd 'does not exist...'(058).
  ENDIF.

AT SELECTION-SCREEN OUTPUT.
* This commented out code can be used to add a function on the toolbar:
  st_smp_dyntxt-text       = 'Information'(027) ##TEXT_DUP.
  st_smp_dyntxt-icon_id    = '@0S@'.
  st_smp_dyntxt-icon_text  = 'Info'(024).
  st_smp_dyntxt-quickinfo  = 'General Info'(028).
  st_smp_dyntxt-path       = 'I'.
  sscrfields-functxt_01    = st_smp_dyntxt.

  LOOP AT SCREEN.
    CASE screen-group1.
      WHEN 'SEL'.
        IF p_sel = 'X'.
          screen-active = '1'.
          sc_b20 = 'Selection criteria'(b21).
        ELSE.
          screen-active = '0'.
          sc_b20 = 'File upload'(b22).
        ENDIF.
        MODIFY SCREEN.
      WHEN 'CHK'.
        IF p_sel = 'X'.
          screen-active = '1'.
        ELSE.
          screen-active = '0'.
        ENDIF.
        MODIFY SCREEN.
      WHEN 'BUF'.
        IF p_buff = 'X'.
          screen-active = '1'.
        ELSE.
          screen-active = '0'.
        ENDIF.
        MODIFY SCREEN.
      WHEN 'DIC'.
        IF p_sel = 'X'.
          screen-active = '1'.
        ELSE.
          screen-active = '0'.
        ENDIF.
        MODIFY SCREEN.
      WHEN 'KEY'.
        IF p_chkky = 'X' AND p_sel = 'X'.
          screen-active = '1'.
        ELSE.
          screen-active = '0'.
        ENDIF.
        MODIFY SCREEN.
      WHEN 'UPL'.
        IF p_upl = 'X'.
          screen-active = '1'.
        ELSE.
          screen-active = '0'.
        ENDIF.
        MODIFY SCREEN.
      WHEN 'GRY'.
        screen-input = '0'.
        MODIFY SCREEN.
    ENDCASE.
  ENDLOOP.

* If the user range is initial (removed manually), set the correct Icon:
AT SELECTION-SCREEN ON s_user.
  IF s_user[] IS INITIAL.
    sc_name = '@LD@'.
  ENDIF.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  p_file = rf_ztct->get_filename( ).

*--------------------------------------------------------------------*
*       CLASS lcl_eventhandler_ztct IMPLEMENTATION
*--------------------------------------------------------------------*
CLASS lcl_eventhandler_ztct IMPLEMENTATION.

  METHOD on_function_click.
    TYPES ty_string TYPE string.
    DATA lt_range_transports_to_add TYPE RANGE OF e070-trkorr.
    DATA ls_range_transports_to_add LIKE LINE OF lt_range_transports_to_add.
*   Selected rows
    DATA lr_selections       TYPE REF TO cl_salv_selections.
    DATA lt_rows             TYPE salv_t_row.
    DATA ls_cell             TYPE salv_s_cell.

* Inline data declarations. Preferred by AbapLint, but should not be
* declared within conditional blocks (IF, ELSE, CASE).
    DATA(lp_filename)  = VALUE ty_string( ).

*   Which popup are we displaying? Conflicts or Table keys?
    FIELD-SYMBOLS <lf_ref_table> TYPE REF TO cl_salv_table.
    IF rf_conflicts IS BOUND.
      ASSIGN rf_conflicts TO <lf_ref_table>.              "#EC CI_SUBRC
    ELSEIF rf_table_keys IS BOUND.
      ASSIGN rf_table_keys TO <lf_ref_table>.             "#EC CI_SUBRC
    ELSE.
      ASSIGN rf_table TO <lf_ref_table>.                  "#EC CI_SUBRC
    ENDIF.
    IF <lf_ref_table> IS ASSIGNED.
*     Get current row
      lr_selections = <lf_ref_table>->get_selections( ).
      lt_rows       = lr_selections->get_selected_rows( ).
      ls_cell       = lr_selections->get_current_cell( ).
      IF e_salv_function <> 'GOON' AND e_salv_function <> 'ABR'.
        READ TABLE rf_ztct->main_list INTO rf_ztct->main_list_line
                                     INDEX ls_cell-row.   "#EC CI_SUBRC
      ENDIF.
      CASE e_salv_function.
        WHEN 'GOON'.
          rf_ztct->ofc_goon( EXPORTING im_rows  = lt_rows
                              CHANGING ch_table = <lf_ref_table> ).
        WHEN 'ABR'.
          rf_ztct->ofc_abr( CHANGING ch_conflicts = rf_conflicts ).
        WHEN 'RECHECK'.
          rf_ztct->set_building_conflict_popup( abap_false ).
          rf_ztct->refresh_import_queues( ).
          rf_ztct->flag_for_process( im_rows = lt_rows
                                     im_cell = ls_cell ).
          rf_ztct->add_table_keys_to_list( CHANGING ch_table = rf_ztct->main_list ).
          rf_ztct->get_additional_tp_info( CHANGING ch_table = rf_ztct->main_list ).
          rf_ztct->flag_same_objects( CHANGING ch_main_list = rf_ztct->main_list ).
          rf_ztct->check_for_conflicts( CHANGING ch_main_list = rf_ztct->main_list ).
        WHEN 'DDIC'.
          rf_ztct->ofc_ddic( ).
        WHEN '&ADD'.
          rf_ztct->set_building_conflict_popup( ).
*         Here, we want to give the option to the user to select the
*         transports to be added. Display a popup with the option to select the
*         transports to be added with checkboxes.
          rf_ztct->flag_for_process( im_rows = lt_rows
                                     im_cell = ls_cell ).
          rf_ztct->flag_same_objects( CHANGING ch_main_list = rf_ztct->main_list ).
          rf_ztct->check_for_conflicts( CHANGING ch_main_list = rf_ztct->main_list ).
          rf_ztct->build_conflict_popup( im_rows = lt_rows
                                         im_cell = ls_cell ).
        WHEN '&ADD_TP'.
          rf_ztct->ofc_add_tp( ).
        WHEN '&ADD_FILE'.
          rf_ztct->clear_flags( ).
          lp_filename = rf_ztct->get_filename( ).
          rf_ztct->gui_upload( lp_filename ).
          tp_dokl_object = 'ZEV_TP_CHECKTOOL_ADD_FILE'.
          rf_ztct->docu_call( im_object     = tp_dokl_object
                              im_id         = 'TX'
                              im_display    = abap_true
                              im_displ_mode = '2' ).
          rf_ztct->check_for_conflicts( CHANGING ch_main_list = rf_ztct->main_list ).
        WHEN '&DEL'.
*         Mark all records for the selected transport(s)
          rf_ztct->clear_flags( ).
          rf_ztct->mark_all_tp_records( EXPORTING im_cell = ls_cell
                                        CHANGING  ch_rows = lt_rows ).
          rf_ztct->flag_for_process( im_rows = lt_rows
                                     im_cell = ls_cell ).
          rf_ztct->flag_same_objects( CHANGING ch_main_list = rf_ztct->main_list ).
          rf_ztct->delete_tp_from_list( lt_rows ).
          rf_ztct->check_for_conflicts( CHANGING ch_main_list = rf_ztct->main_list ).
        WHEN '&IMPORT'.
*         Re-transport a request (transport already in production)
          rf_ztct->clear_flags( ).
          rf_ztct->flag_for_process( im_rows = lt_rows
                                     im_cell = ls_cell ).
          FREE lt_range_transports_to_add.
          CLEAR ls_range_transports_to_add.
          ls_range_transports_to_add-sign   = 'I'.
          ls_range_transports_to_add-option = 'EQ'.
          LOOP AT rf_ztct->main_list INTO rf_ztct->main_list_line
                                    WHERE flag = 'X'
                                      AND prd  = rf_ztct->co_okay.
            ls_range_transports_to_add-low = rf_ztct->main_list_line-trkorr.
            APPEND ls_range_transports_to_add TO lt_range_transports_to_add.
          ENDLOOP.
          IF lt_range_transports_to_add IS INITIAL.
            MESSAGE i000(db) WITH 'No records selected that can be re-imported'(m11).
            RETURN.
          ENDIF.
          LOOP AT rf_ztct->main_list INTO rf_ztct->main_list_line
                                    WHERE trkorr IN lt_range_transports_to_add.
            rf_ztct->main_list_line-flag = 'X'.
            rf_ztct->main_list_line-prd  = rf_ztct->co_scrap.
            MODIFY rf_ztct->main_list FROM rf_ztct->main_list_line.
          ENDLOOP.
          rf_ztct->flag_same_objects( CHANGING ch_main_list = rf_ztct->main_list ).
          rf_ztct->check_for_conflicts( CHANGING ch_main_list = rf_ztct->main_list ).
        WHEN '&DOC'.
          tp_dokl_object = rf_ztct->main_list_line-trkorr.
          rf_ztct->docu_call( im_object = tp_dokl_object
                              im_id     = 'TA' ).
          rf_ztct->check_documentation( EXPORTING im_trkorr = rf_ztct->main_list_line-trkorr
                                        CHANGING  ch_table  = rf_ztct->main_list ).
        WHEN '&PREP_XLS'.
          IF rf_table_xls IS BOUND.
            RETURN.
          ENDIF.
          rf_ztct->display_excel( rf_ztct->main_list ).
        WHEN '&SAVE'.
          rf_ztct->ofc_save( ).
        WHEN '&NCONF'.
          rf_ztct->ofc_nconf( EXPORTING im_selections = lr_selections
                              CHANGING  ch_cell       = ls_cell ).
      ENDCASE.
      IF rf_table IS BOUND.
        rf_ztct->refresh_alv( ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD on_double_click.
    DATA lr_selections TYPE REF TO cl_salv_selections.
*   Selected rows
    DATA lt_rows       TYPE salv_t_row.
    DATA ls_cell       TYPE salv_s_cell.

    lr_selections = rf_table->get_selections( ).
    lt_rows = lr_selections->get_selected_rows( ).
    ls_cell = lr_selections->get_current_cell( ).

*   Only display the details when the list is the MAIN list (Object level
*   not when the list is on Header level (XLS)
    IF rf_table_xls IS BOUND.
      RETURN.
    ELSE.
      READ TABLE rf_ztct->main_list INTO rf_ztct->main_list_line INDEX row.
      IF sy-subrc = 0.
        CASE column.
          WHEN 'TRKORR'.
            rf_ztct->display_transport( rf_ztct->main_list_line-trkorr ).
          WHEN 'AS4USER'.
            rf_ztct->display_user( rf_ztct->main_list_line-as4user ).
          WHEN 'CHECKED_BY'.
            rf_ztct->display_user( rf_ztct->main_list_line-checked_by ).
*         Documentation
          WHEN 'INFO'.
            rf_ztct->display_docu( rf_ztct->main_list_line-trkorr ).
            rf_ztct->refresh_alv( ).
          WHEN 'WARNING_LVL'.
*           Display popup with the conflicting transports/objects
            IF rf_ztct->main_list_line-warning_lvl IS NOT INITIAL.
              rf_ztct->build_conflict_popup( im_rows = lt_rows
                                             im_cell = ls_cell ).
              rf_ztct->refresh_alv( ).
            ENDIF.
        ENDCASE.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD on_double_click_popup.
    READ TABLE rf_ztct->conflicts INTO rf_ztct->conflict_line INDEX row.
    IF sy-subrc = 0.
      CASE column.
        WHEN 'TRKORR'.
          rf_ztct->display_transport( rf_ztct->conflict_line-trkorr ).
        WHEN 'AS4USER'.
          rf_ztct->display_user( rf_ztct->conflict_line-as4user ).
        WHEN 'CHECKED_BY'.
          rf_ztct->display_user( rf_ztct->conflict_line-checked_by ).
*     Documentation
        WHEN 'INFO'.
          rf_ztct->display_docu( rf_ztct->conflict_line-trkorr ).
          rf_ztct->refresh_alv( ).
      ENDCASE.
    ENDIF.
  ENDMETHOD.

  METHOD on_link_click.
*   Which table are we displaying? Object level or Header level (XLS)?
    IF rf_table_xls IS BOUND.
      READ TABLE rf_ztct->main_list_xls INTO rf_ztct->main_list_line INDEX row. "#EC CI_SUBRC
    ELSE.
      READ TABLE rf_ztct->main_list INTO rf_ztct->main_list_line INDEX row. "#EC CI_SUBRC
    ENDIF.
    CASE column.
      WHEN 'TRKORR'.
        rf_ztct->display_transport( rf_ztct->main_list_line-trkorr ).
      WHEN 'OBJ_NAME'.
        CALL FUNCTION 'TR_OBJECT_JUMP_TO_TOOL'
          EXPORTING
            iv_pgmid    = rf_ztct->main_list_line-pgmid
            iv_object   = rf_ztct->main_list_line-object
            iv_obj_name = rf_ztct->main_list_line-obj_name
            iv_action   = 'SHOW'
          EXCEPTIONS
            OTHERS      = 1.
        IF sy-subrc <> 0.
          CALL FUNCTION 'TR_OBJECT_JUMP_TO_TOOL'
            EXPORTING
              iv_pgmid    = 'LIMU'
              iv_object   = rf_ztct->main_list_line-object
              iv_obj_name = rf_ztct->main_list_line-obj_name
              iv_action   = 'SHOW'
            EXCEPTIONS
              OTHERS      = 1.
          IF sy-subrc <> 0.
            MESSAGE i000(db) WITH 'Object cannot be displayed...'(m14).
          ENDIF.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD on_link_click_popup.
    READ TABLE rf_ztct->conflicts INTO rf_ztct->conflict_line INDEX row.
    IF sy-subrc = 0 AND column = 'TRKORR'.
      rf_ztct->display_transport( rf_ztct->conflict_line-trkorr ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

*--------------------------------------------------------------------*
*       CLASS lcl_ztct IMPLEMENTATION
*--------------------------------------------------------------------*
CLASS lcl_ztct IMPLEMENTATION.

  METHOD constructor.
    lp_alert0_text = 'Log couldn''t be read or TP not released'(w16).
    lp_alert1_text = 'Transport not released'(w19).
    lp_alert2_text = 'Release started'(w20).
    lp_alert3_text = 'Transport not in Transport Buffer'(m12).
    lp_hint1_text  = 'Newer version in test environment, but in list'(w22).
    lp_hint2_text  = 'Conflicts are dealt with'(w04).
    lp_hint3_text  = 'Couldn''t read log, but object in list'(w21).
    lp_hint4_text  = 'Overwrites version(s), newer version in list'(w11).
    lp_warn_text   = 'Previous transport not transported'(w17).
    lp_error_text  = 'Newer version in target environment!'(w01).
    lp_ddic_text   = 'Uses object not in list or target environment'(w03).
    lp_info_text   = 'Newer version in test environment'(w23).
    lp_fail_text   = 'Transport not possible'(w24).
* Create a range table containing all project transport numbers.
* When selecting transports, these can be skipped.
* Create a range table containing all project numbers:
    SELECT 'I' AS sign,
           'EQ' AS option,
           trkorr AS low
           FROM ctsproject
           INTO CORRESPONDING FIELDS OF TABLE @project_trkorrs
           ORDER BY low.                 "#EC CI_SGLSELECT #EC CI_SUBRC
*   Ensure that the range cannot be empty
    IF project_trkorrs IS INITIAL.
      project_trkorrs = VALUE ty_range_trkorr( ( sign   = 'I'
                                                 option = 'EQ'
                                                 low    = 'DUMMY' ) ).
    ENDIF.
  ENDMETHOD.

  METHOD execute.
    IF process_type = 1.
      get_data( trkorr_range ).
      get_additional_tp_info( CHANGING ch_table = main_list ).
*     First selection: If the flag to exclude transport that are already
*     in production is set, remove all these transports from the main
*     list.
      IF skiplive IS NOT INITIAL.
        remove_tp_in_prd( ).
      ENDIF.
*     Table checks not possible for version checking.
      IF process_type = 1.
        build_table_keys_popup( ).
        FREE rf_table_keys.
        add_table_keys_to_list( CHANGING ch_table = main_list ).
      ENDIF.
* Reason to check data dictionary objects:
* If objects in the transport list contain DDIC objects that do NOT
* exist in production and do NOT exist in the transport list, errors
* (DUMPS) will happen when the transports are moved to production.
* Checking steps:
*   1. Get all Z-objects in tables DD01L, DD02L and DD04L (Domains,
*      Tables, Elements)
*   2. Get all transports from E071 containing these objects
*   3. Store the link between Transports and Objects in attribute WHERE_USED
*   4. Remove from the table all records for objects/transports that have
*       been transported to production
*   5. Execute a Where-Used on all remaining objects
*   6. If there are Objects in the main transport list, that are ALSO in
*     the Where-Used list then THE TRANSPORT CANNOT GO TO PRODUCTION!
      IF check_ddic = abap_true.
        prepare_ddic_check( ).
      ENDIF.
      check_for_conflicts( CHANGING ch_main_list = main_list ).
    ELSEIF gui_upload( filename ) = abap_true.
      RETURN.
    ENDIF.

    set_color( ).
    alv_init( ).
    alv_set_properties( rf_table ).
    alv_set_lr_tooltips( rf_table ).
    alv_output( ).
  ENDMETHOD.

  METHOD get_data.
    refresh_import_queues( ).
    get_main_transports( im_trkorr_range ).
  ENDMETHOD.

  METHOD get_tp_prefix.
    IF prefix IS INITIAL.
*     Build transport prefix
      IF im_dev IS SUPPLIED.
        set_tp_prefix( im_dev ).
      ELSE.
        set_tp_prefix( ).
      ENDIF.
    ENDIF.
    re_tp_prefix = prefix.
  ENDMETHOD.

  METHOD set_tp_prefix.
*   Build transport prefix:
    IF im_dev IS SUPPLIED.
      CONCATENATE im_dev 'K%' INTO prefix.
    ELSE.
      CONCATENATE sy-sysid 'K%' INTO prefix.
    ENDIF.
  ENDMETHOD.

  METHOD refresh_import_queues.
    CALL FUNCTION 'TMS_MGR_REFRESH_IMPORT_QUEUES'.
  ENDMETHOD.

  METHOD flag_for_process.
    DATA ls_row    TYPE int4.
    IF im_rows IS INITIAL AND im_cell IS INITIAL.
      MESSAGE i000(db) WITH 'Please select records or put the cursor on a row'(m10).
      RETURN.
    ENDIF.
*   First clear all the flags:
    clear_flags( ).
*   If the DDIC check is OFF, but there ARE DDIC warnings in the list,
*   then we need to flag these records to be checked. If that is not
*   done then the DDIC warning icon would stay, even if the missing
*   DDIC object would be added to the list...
    IF check_ddic = abap_false.
      LOOP AT main_list INTO main_list_line
                       WHERE warning_lvl = co_ddic.
        main_list_line-flag = abap_true.
        MODIFY main_list FROM main_list_line INDEX sy-tabix TRANSPORTING flag.
      ENDLOOP.
    ENDIF.
*   If row(s) are selected, use the table
    LOOP AT im_rows INTO ls_row.
      main_list_line-flag = abap_true.
      MODIFY main_list FROM main_list_line INDEX ls_row TRANSPORTING flag.
    ENDLOOP.
*   If no rows were selected, take the current cell instead
    IF sy-subrc <> 0.
      READ TABLE main_list INTO main_list_line INDEX im_cell-row.
      IF sy-subrc = 0.
        main_list_line-flag = abap_true.
        MODIFY main_list FROM main_list_line INDEX im_cell-row TRANSPORTING flag.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD check_for_conflicts.
    DATA lp_counter           TYPE i.
    DATA lp_tabix             TYPE sytabix.
    DATA ls_main              TYPE ty_request_details.
    DATA lt_newer_transports  TYPE ty_request_details_tt.
    DATA lt_older_transports  TYPE ty_request_details_tt.
    DATA lp_domnam            TYPE char10.
    DATA lp_highest_lvl       TYPE icon_d.
    DATA lp_highest_rank      TYPE numc4.
    DATA lp_highest_text      TYPE text74.
    DATA lp_highest_col       TYPE lvc_t_scol.

    FREE conflicts.
    CLEAR conflict_line.
    CLEAR total.
    IF check_flag = abap_false.
      RETURN.
    ENDIF.
    sort_list( CHANGING ch_list = main_list ).
*   For each transports, all the objects in the transport will be checked.
*   If there is a newer version of an object in prd, then a warning will
*   be displayed. Also if a newer version that was in prd was actually
*   overwritten or if an object could not be checked.
*   Total for progress indicator: How many will be checked?
    CLEAR lp_counter.
    LOOP AT ch_main_list INTO ls_main WHERE prd <> co_okay
                                        AND dev <> co_error
                                        AND flag = abap_true.
      total = total + 1.
    ENDLOOP.

*   Check each object in the main list, that has been flagged (also allow
*   checking of transports in prd, those may have been added for transport
*   again):
    LOOP AT ch_main_list INTO ls_main WHERE prd  <> co_okay
                                        AND dev  <> co_error
                                        AND flag = abap_true.
      CLEAR conflict_line.
      CLEAR ls_main-warning_lvl.
      CLEAR ls_main-warning_rank.
      CLEAR ls_main-warning_txt.
      lp_tabix = sy-tabix.
*     Show the progress indicator
      lp_counter = lp_counter + 1.
      progress_indicator( im_counter = lp_counter
                          im_object  = ls_main-obj_name
                          im_total   = total
                          im_text    = 'Objects checked'(011)
                          im_flag    = ' ' ).
*     The CHECKED flag is useful to check if the check has been carried
*     out. On the selection screen, you can choose to clear the flags
*     (which can be useful if the file is old and needs to be rechecked)
*     This flag will aid the user when the user checks the list in
*     stages (Example: Half today and the other half tomorrow).
*     st_main-checked is set here to 'X'. It will be updated later when
*     the check has been executed and the main list updated with the
*     change.
      ls_main-checked = co_checked.
      MODIFY ch_main_list FROM ls_main TRANSPORTING checked.
*     Check for documentation:
      check_documentation( EXPORTING im_trkorr = ls_main-trkorr
                           CHANGING  ch_table  = ch_main_list ).
*     Now check the object:
      get_tps_for_same_object( EXPORTING im_line  = ls_main
                               IMPORTING ex_newer = lt_newer_transports
                                         ex_older = lt_older_transports ).
*     Compare version in QAS with version in prd
*     If a newer version/request is found in prd, then add a warning and
*     continue with the next.
      IF lt_newer_transports[] IS NOT INITIAL.
        check_newer_transports( EXPORTING im_newer_transports = lt_newer_transports
                                          im_main_list        = ch_main_list
                                CHANGING  ch_conflicts        = conflicts
                                          ch_main             = ls_main ).
      ENDIF.
*     Select all the transports that are older. These will be checked to
*     see if they have been moved to prd. If the older version has been
*     transported, it is okay.
*     If not, then add a warning and continue with the next record.
      IF lt_older_transports[] IS NOT INITIAL.
        check_older_transports( EXPORTING im_older_transports = lt_older_transports
                                          im_main_list        = ch_main_list
                                CHANGING  ch_conflicts        = conflicts
                                          ch_main             = ls_main ).
      ENDIF.
*     Determine highest warning level in conflict list
*     Only when NOT building the conflict popup
      IF building_conflict_popup = abap_false.
        CLEAR: lp_highest_lvl,
               lp_highest_rank,
               lp_highest_text,
               lp_highest_col.
        LOOP AT conflicts INTO conflict_line.
          IF conflict_line-warning_rank > lp_highest_rank.
            lp_highest_lvl  = conflict_line-warning_lvl.
            lp_highest_rank = conflict_line-warning_rank.
            lp_highest_col  = conflict_line-t_color.
            lp_highest_text = determine_warning_text( lp_highest_rank ).
          ENDIF.
        ENDLOOP.
        ls_main-warning_lvl  = lp_highest_lvl.
        ls_main-warning_rank = lp_highest_rank.
        ls_main-warning_txt  = lp_highest_text.
        ls_main-t_color      = lp_highest_col.
        MODIFY ch_main_list FROM ls_main TRANSPORTING warning_lvl
                                                      warning_rank
                                                      warning_txt
                                                      t_color.
      ENDIF.
*     Refresh the conflict table. But, if the conflict popup is being build
*     for one or more lines, then do NOT refresh the conflict table. Display
*     ALL conflicts for all selected lines.
      IF building_conflict_popup = abap_false.
        FREE conflicts.
      ENDIF.
    ENDLOOP.

*   Update the conflict table and the main list with DDIC information
    do_ddic_check( CHANGING ch_main_list = ch_main_list ).

*   Check if the transport is in Transport Buffer
*   TMS_MGR_REFRESH_IMPORT_QUEUES updates this table
    CLEAR lp_counter.
*   When checking the buffer, but never when building popup
*   (buffer_chk = abap_true AND building_conflict_popup = abap_false)
    IF buffer_chk = abap_true AND building_conflict_popup = abap_false.
      LOOP AT ch_main_list ASSIGNING FIELD-SYMBOL(<lf_main_list>)
                           WHERE prd  <> co_okay
                             AND prd  <> co_scrap
                             AND dev  <> co_error
                             AND flag = abap_true.
*       Show the progress indicator
        lp_counter = lp_counter + 1.
        progress_indicator( im_counter = lp_counter
                            im_object  = <lf_main_list>-obj_name
                            im_total   = total
                            im_text    = 'Checking buffer'(050)
                            im_flag    = ' ' ).
        CLEAR lp_domnam.
        SELECT SINGLE domnam INTO @lp_domnam FROM tmsbuffer
                            WHERE trkorr = @<lf_main_list>-trkorr
                              AND sysnam = @prd_system ##WARN_OK.
        IF sy-subrc = 4.
          IF buffer_remove_tp = abap_true.
            DELETE ch_main_list INDEX sy-tabix.
          ELSE.
            <lf_main_list>-warning_lvl  = co_alert.
            <lf_main_list>-warning_rank = co_alert3_rank.
            <lf_main_list>-warning_txt  = lp_alert3_text.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.
*   Sort ta_conflicts by date time stamp, descending. Most recent should
*   be displayed first:
    SORT conflicts BY as4date DESCENDING
                      as4time DESCENDING
                      trkorr  DESCENDING.
    DELETE ADJACENT DUPLICATES FROM conflicts
                               COMPARING trkorr object obj_name.
  ENDMETHOD.

  METHOD build_table_keys_popup.
*   A popup is displayed with all tables found in the main list, that
*   have keys. The user has now the option to include them in the
*   checking procedure. This is the only place where the user has a
*   complete overview of the tables that have been found...
*   Declaration for ALV Columns
    DATA lr_columns_table       TYPE REF TO cl_salv_columns_table.
    DATA lr_column_table        TYPE REF TO cl_salv_column_table.
    DATA lt_t_column_ref        TYPE salv_t_column_ref.
    DATA ls_s_column_ref        TYPE salv_s_column_ref.
    DATA lr_events              TYPE REF TO cl_salv_events_table.
*   Declaration for Global Display Settings
    DATA lr_display_settings    TYPE REF TO cl_salv_display_settings.
*   Declaration for Table Selection settings
    DATA lr_selections          TYPE REF TO cl_salv_selections.
    DATA lp_title               TYPE lvc_title.
    DATA lp_tp_prefix           TYPE char5.
    DATA lp_xstart              TYPE i VALUE 26.
    DATA lp_ystart              TYPE i VALUE 7.
    DATA lp_cw_tabname          TYPE lvc_outlen.
    DATA lp_cw_counter          TYPE lvc_outlen.
    DATA lp_cw_ddtext           TYPE lvc_outlen.
*   Texts
    DATA lp_short_text       TYPE char10.
    DATA lp_medium_text      TYPE char20.
    DATA lp_long_text        TYPE char40.

    DATA(lp_xend) = 0.

*   Only if the option to check for table keys is switched ON and
*   checking is active
    IF check_flag = abap_false.
      RETURN.
    ENDIF.
    lp_title = 'Select the tables for which the keys must be checked'(t06).
* Determine the transport prefix (if not done already)
    lp_tp_prefix = get_tp_prefix( dev_system ).
*   Fill the internal table to be displayed in the popup:
    LOOP AT main_list INTO main_list_line
                     WHERE objfunc    = 'K'
                       AND keyobject  IS INITIAL
                       AND keyobjname IS INITIAL
                       AND obj_name   IN excluded_objects.
      CLEAR table_keys_line.
      SELECT SINGLE ddtext FROM dd02t
                           INTO @table_keys_line-ddtext
                          WHERE ddlanguage = @co_langu
                            AND tabname    = @main_list_line-obj_name. "#EC CI_SUBRC
*     Count the keys...
      SELECT COUNT(*)
              FROM e071k INTO @table_keys_line-counter
             WHERE trkorr     = @main_list_line-trkorr
               AND mastertype = @main_list_line-object
               AND trkorr NOT IN @project_trkorrs
               AND trkorr     LIKE @lp_tp_prefix
               AND objname    IN @excluded_objects.       "#EC CI_SUBRC
      table_keys_line-tabname = main_list_line-obj_name.
      COLLECT table_keys_line INTO table_keys.
    ENDLOOP.

    DELETE table_keys WHERE counter = 0.
    IF table_keys[] IS INITIAL.
      RETURN.
    ENDIF.
    SORT table_keys BY counter DESCENDING.

* Only display the popup if the user selected the option 'Check table keys'
* on the selection screen. If not, the popup does not need to be displayed,
* but the tables still need to be added to the list of excluded objects.
* If the user will NOT check the table keys, all tables need to be added to
* the excluded object list (Tables will NOT be checked).
    IF check_tabkeys = abap_false.
      LOOP AT table_keys INTO table_keys_line.
        ls_excluded_objects-sign   = 'E'.
        ls_excluded_objects-option = 'EQ'.
        ls_excluded_objects-low    = table_keys_line-tabname.
        APPEND ls_excluded_objects TO excluded_objects.
      ENDLOOP.
      RETURN.
    ENDIF.

*   Determine total width
    LOOP AT table_keys INTO table_keys_line.
      determine_col_width( EXPORTING im_field    = table_keys_line-tabname
                           CHANGING  ch_colwidth = lp_cw_tabname ).
      determine_col_width( EXPORTING im_field    = table_keys_line-ddtext
                           CHANGING  ch_colwidth = lp_cw_ddtext ).
    ENDLOOP.

    lp_xend = lp_cw_tabname + lp_cw_counter + lp_cw_ddtext.

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = rf_table_keys
          CHANGING
            t_table      = table_keys ).
*   Global display settings
        lr_display_settings = rf_table_keys->get_display_settings( ).
*   Activate Striped Pattern
        lr_display_settings->set_striped_pattern( if_salv_c_bool_sap=>true ).
*   Report header
        lr_display_settings->set_list_header( lp_title ).
*       Table Selection Settings
        lr_selections = rf_table_keys->get_selections( ).
        IF lr_selections IS NOT INITIAL.
*         Allow row and column Selection (Adds checkbox)
          lr_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).
        ENDIF.
*       Get the columns from ALV Table
        lr_columns_table = rf_table_keys->get_columns( ).
        IF lr_columns_table IS NOT INITIAL.
          FREE lt_t_column_ref.
          lt_t_column_ref = lr_columns_table->get( ).
*         Get columns properties
          lr_columns_table->set_optimize( if_salv_c_bool_sap=>true ).
          lr_columns_table->set_key_fixation( if_salv_c_bool_sap=>true ).
*         Individual Column Properties.
          LOOP AT lt_t_column_ref INTO ls_s_column_ref.
            TRY.
                lr_column_table ?=
                  lr_columns_table->get_column( ls_s_column_ref-columnname ).
              CATCH cx_salv_not_found INTO rf_root.
                handle_error( rf_root ).
            ENDTRY.
            IF lr_column_table->get_columnname( ) = 'COUNTER'.
              lp_short_text  = 'Counter'(040).
              lp_medium_text = 'Counter'(040).
              lp_long_text   = 'Counter'(040).
              lr_column_table->set_short_text( lp_short_text ).
              lr_column_table->set_medium_text( lp_medium_text ).
              lr_column_table->set_long_text( lp_long_text ).
              lr_column_table->set_alignment( if_salv_c_alignment=>centered ).
            ENDIF.
          ENDLOOP.
        ENDIF.
*       Register handler for actions
        lr_events = rf_table_keys->get_event( ).
        SET HANDLER lcl_eventhandler_ztct=>on_function_click FOR lr_events.
*       Save reference to access object from handler
        lcl_eventhandler_ztct=>rf_table_keys = rf_table_keys.
*       Use gui-status ST850 from program SAPLKKB
        rf_table_keys->set_screen_status( pfstatus = 'ST850'
                                          report   = 'SAPLKKBL' ).
*       Determine the size of the popup window:
        lp_xend = lp_xend + lp_xstart + 5.
        DATA(lp_yend) = lines( table_keys ) + lp_ystart.
        IF lp_yend > 30.
          lp_yend = 30.
        ENDIF.
*       Display as popup
        rf_table_keys->set_screen_popup( start_column = lp_xstart
                                         end_column   = lp_xend
                                         start_line   = lp_ystart
                                         end_line     = lp_yend ).
        rf_table_keys->display( ).
      CATCH cx_salv_msg INTO rf_root.
        handle_error( rf_root ).
    ENDTRY.

  ENDMETHOD.

  METHOD add_table_keys_to_list.
    DATA lt_keys_main        TYPE ty_request_details_tt.
    DATA ls_keys_main        TYPE ty_request_details.
    DATA ls_keys             TYPE ty_request_details.
*   Only if the option to check for table keys is switched ON, on the
*   selection screen:
    IF check_tabkeys = abap_false.
      RETURN.
    ENDIF.
*   Check if keys exist in table E071K. Only do this for the records
*   that have not been added already (without key object and name)
*   Remove the entries for which that is the case and add the objects
*   with the keys.
*   s_exobj contains all tables that we do not want to check.
    LOOP AT ch_table INTO ls_keys_main WHERE objfunc    = 'K'
                                         AND keyobject  IS INITIAL
                                         AND keyobjname IS INITIAL
                                         AND obj_name   IN excluded_objects.
      APPEND ls_keys_main TO lt_keys_main.
      DELETE TABLE ch_table FROM ls_keys_main.
    ENDLOOP.

    LOOP AT lt_keys_main INTO ls_keys.
      SELECT object AS keyobject,
             objname AS keyobjname,
             tabkey
             FROM e071k
             INNER JOIN e070 ON e070~trkorr = e071k~trkorr
             INTO CORRESPONDING FIELDS OF @ls_keys
             WHERE e071k~trkorr     = @ls_keys-trkorr
               AND e071k~trkorr     NOT IN @project_trkorrs
               AND e071k~trkorr     LIKE @prefix
               AND e070~trfunction  <> 'T'
               AND e071k~mastertype = @ls_keys-object
               AND e071k~mastername = @ls_keys-obj_name(40)
               AND e071k~objname    IN @excluded_objects.
        APPEND ls_keys TO ch_table.
      ENDSELECT.
    ENDLOOP.

  ENDMETHOD.

  METHOD progress_indicator.
    DATA lp_gprogtext         TYPE char1024.
    DATA lp_string            TYPE string.
    DATA lp_total             TYPE numc10.
*   IM_TOTAL cannot be changed, and we need to remove the leading
*   zero's. That is why intermediate parameter lp_total was added
    lp_total = im_total.
    DATA(lp_difference) = lp_total - im_counter.
    DATA(lp_step) = 1.
    DATA(lp_counter_reset) = 0.
*   Determine step size
    IF im_flag = abap_true.
      IF lp_difference < 100.
        lp_step = 1.
      ELSEIF lp_difference < 1000.
        lp_step = 50.
      ELSE.
        lp_step = 100.
      ENDIF.
    ENDIF.
*   Number of selected items on GUI:
    IF lp_step = 0.
      RETURN.
    ENDIF.
    DATA(lp_gproggui) = im_counter MOD lp_step.
    IF lp_gproggui = 0.
      WRITE im_counter TO lp_gprogtext LEFT-JUSTIFIED.
      IF lp_total <> 0.
        SHIFT lp_total LEFT DELETING LEADING '0'.
        CONCATENATE lp_gprogtext 'of' lp_total
                    INTO lp_gprogtext SEPARATED BY ' '.
      ENDIF.
      IF im_object IS NOT INITIAL.
        CONCATENATE '(' im_object ')'
                    INTO lp_string.
        CONDENSE lp_string.
      ENDIF.
      CONCATENATE lp_gprogtext im_text lp_string
                  INTO lp_gprogtext
                  SEPARATED BY ' '.
      CONDENSE lp_gprogtext.

      cl_progress_indicator=>progress_indicate(
          i_text               = lp_gprogtext
          i_processed          = im_counter
          i_total              = im_total
          i_output_immediately = abap_true ).

    ENDIF.

* To avoid timeouts
    IF check_tabkeys = abap_true.
      lp_counter_reset = im_counter MOD 5.
    ELSE.
      lp_counter_reset = im_counter MOD 50.
    ENDIF.

    IF lp_counter_reset = 0.
      CALL FUNCTION 'TH_REDISPATCH'.
    ENDIF.

  ENDMETHOD.

  METHOD get_main_transports.
    DATA lt_main_list_vrsd  TYPE ty_request_details_tt.
    DATA ls_main_list_vrsd  TYPE ty_request_details.
    FIELD-SYMBOLS <lf_main_list> TYPE ty_request_details.
    FREE lt_main_list_vrsd.

    cl_progress_indicator=>progress_indicate( i_text = 'Selecting data...'(014) ).

*   Join over E070, E071:
*   Description is read later to prevent complicated join and
*   increased runtime
    SELECT a~trkorr,   a~trfunction, a~trstatus,
           a~as4user,  a~as4date,    a~as4time,
           b~pgmid,    b~object,     b~obj_name,
           b~objfunc
           INTO CORRESPONDING FIELDS OF TABLE @main_list
           FROM  e070 AS a JOIN e071 AS b
             ON  a~trkorr  = b~trkorr
           WHERE a~trkorr  IN @im_trkorr_range
             AND strkorr   = ''
             AND a~trkorr  LIKE @prefix
             AND ( pgmid   = 'LIMU' OR
                   pgmid   = 'R3TR' )
           ORDER BY a~trkorr ##TOO_MANY_ITAB_FIELDS.      "#EC CI_SUBRC
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    IF main_list[] IS NOT INITIAL.
      LOOP AT main_list ASSIGNING <lf_main_list>.
*       If the transports should be checked, flag it.
        <lf_main_list>-flag = abap_true.
*       Read transport description:
        SELECT SINGLE as4text
                 FROM e07t
                 INTO @<lf_main_list>-tr_descr
                WHERE trkorr = @<lf_main_list>-trkorr.    "#EC CI_SUBRC
      ENDLOOP.
    ENDIF.
    SORT main_list.
    DELETE ADJACENT DUPLICATES FROM main_list.
*   Check if project is in selection range:
    IF project_range IS NOT INITIAL.
      LOOP AT main_list ASSIGNING <lf_main_list>.
        SELECT SINGLE reference
                 FROM e070a
                 INTO @<lf_main_list>-project
                WHERE trkorr = @<lf_main_list>-trkorr
                  AND attribute = 'SAP_CTS_PROJECT'
                  AND reference IN @project_range.        "#EC CI_SUBRC
        IF sy-subrc <> 0.
          DELETE main_list INDEX sy-tabix.
        ENDIF.
      ENDLOOP.
    ENDIF.
*   Only continue if there are transports left to check
    IF main_list IS INITIAL.
      RETURN.
    ELSE.
*   Also read from the version table VRSD. This table contains all
*   dependent objects. For example: If from E071 a function group
*   is retrieved, VRSD will contain all functions too.
      SELECT korrnum, objtype, objname,
             author, datum, zeit
             FROM vrsd
             INTO (@ls_main_list_vrsd-trkorr,
                   @ls_main_list_vrsd-object,
                   @ls_main_list_vrsd-obj_name,
                   @ls_main_list_vrsd-as4user,
                   @ls_main_list_vrsd-as4date,
                   @ls_main_list_vrsd-as4time)
             FOR ALL ENTRIES IN @main_list
             WHERE korrnum = @main_list-trkorr.
        READ TABLE main_list INTO main_list_line
                             WITH KEY trkorr = ls_main_list_vrsd-trkorr.
        IF sy-subrc = 0.
          main_list_line-object   = ls_main_list_vrsd-object.
          main_list_line-obj_name = ls_main_list_vrsd-obj_name.
          main_list_line-as4user  = ls_main_list_vrsd-as4user.
          main_list_line-as4date  = ls_main_list_vrsd-as4date.
          main_list_line-as4time  = ls_main_list_vrsd-as4time.
*       Only append if the object from VRSD does not already exist in the
*       main list:
          IF NOT line_exists( main_list[ trkorr   = main_list_line-trkorr
                                         object   = main_list_line-object
                                         obj_name = main_list_line-obj_name ] ).
            main_list_line-flag = abap_true.
            APPEND main_list_line TO lt_main_list_vrsd.
          ENDIF.
        ENDIF.
      ENDSELECT.
    ENDIF.
*   Duplicates may exist if the same object exists in different tasks
*   belonging to the same request:
    SORT lt_main_list_vrsd DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_main_list_vrsd
                    COMPARING trkorr object obj_name.
*   Now add all VRSD entries to the main list:
    APPEND LINES OF lt_main_list_vrsd TO main_list.
    sort_list( CHANGING ch_list = main_list ).
  ENDMETHOD.

  METHOD get_tp_info.
*   Join over E070, E071:
*   Description is read later to prevent complicated join and
*   increased runtime
    SELECT SINGLE a~trkorr, a~trfunction, a~trstatus,
                  a~as4user, a~as4date, a~as4time,
                  b~object, b~obj_name
            INTO (@re_line-trkorr,
                  @re_line-trfunction,
                  @re_line-trstatus,
                  @re_line-as4user,
                  @re_line-as4date,
                  @re_line-as4time,
                  @re_line-object,
                  @re_line-obj_name)
            FROM e070 AS a JOIN e071 AS b
              ON a~trkorr   = b~trkorr
           WHERE a~trkorr   = @im_trkorr
             AND strkorr    = ''
             AND b~obj_name = @im_obj_name.               "#EC CI_SUBRC
*   Read transport description:
    SELECT SINGLE as4text
             FROM e07t
             INTO @re_line-tr_descr
            WHERE trkorr = @im_trkorr.                    "#EC CI_SUBRC
    re_line-checked_by = sy-uname.
*   First get the descriptions (Status/Type/Project):
*   Retrieve texts for Status Description
    SELECT SINGLE ddtext
             FROM dd07t
             INTO @re_line-status_text
            WHERE domname    = 'TRSTATUS'
              AND ddlanguage = @co_langu
              AND domvalue_l = @re_line-trstatus.         "#EC CI_SUBRC
*   Retrieve texts for Description of request/task type
    SELECT SINGLE ddtext
             FROM dd07t
             INTO @re_line-trfunction_txt
            WHERE domname    = 'TRFUNCTION'
              AND ddlanguage = @co_langu
              AND domvalue_l = @re_line-trfunction.       "#EC CI_SUBRC
*   Retrieve the project number (and description):
    SELECT SINGLE reference
             FROM e070a
             INTO @re_line-project
            WHERE trkorr    = @re_line-trkorr
              AND attribute = 'SAP_CTS_PROJECT'.
    IF sy-subrc = 0.
      SELECT SINGLE descriptn
               FROM ctsproject
               INTO @re_line-project_descr
              WHERE trkorr  = @re_line-project.           "#EC CI_SUBRC
    ENDIF.
*   Retrieve the description of the status
    SELECT SINGLE ddtext
             FROM dd07t
             INTO @re_line-trstatus
            WHERE domname    = 'TRSTATUS'
              AND ddlanguage = @co_langu
              AND domvalue_l = @re_line-trstatus.         "#EC CI_SUBRC

  ENDMETHOD.

  METHOD get_added_objects.
    DATA lp_tabix          TYPE sytabix.
    DATA ls_main           TYPE ty_request_details.
    DATA ls_main_list_vrsd TYPE ty_request_details.
    DATA lt_main_list_vrsd TYPE ty_request_details_tt.
    DATA ls_added          TYPE ty_request_details.
    FIELD-SYMBOLS <lf_main_list> TYPE ty_request_details.
    FREE re_to_add.
    FREE lt_main_list_vrsd.
    CLEAR ls_main.
*   Select all requests (not tasks) in the range. Objects belonging to
*   the request are included in the table.
    SELECT a~trkorr,  a~trfunction, a~trstatus,
           a~as4user, a~as4date,    a~as4time,
           b~pgmid,   b~object,     b~obj_name,
           b~objfunc
           INTO CORRESPONDING FIELDS OF TABLE @re_to_add
           FROM  e070 AS a JOIN e071 AS b
             ON  a~trkorr = b~trkorr
           WHERE a~trkorr IN @im_to_add
           AND   a~strkorr = ''
           AND   ( b~pgmid = 'LIMU' OR
                   b~pgmid = 'R3TR' OR
                   b~pgmid = 'R3OB' OR
                   b~pgmid = 'LANG' )
           ORDER BY a~trkorr ASCENDING, b~as4pos ASCENDING ##TOO_MANY_ITAB_FIELDS.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
*   Read transport description:
    IF re_to_add[] IS NOT INITIAL.
      LOOP AT re_to_add ASSIGNING <lf_main_list>.
        <lf_main_list>-flag = abap_true.
        SELECT SINGLE as4text
                 FROM e07t
                 INTO @<lf_main_list>-tr_descr
                WHERE trkorr = @<lf_main_list>-trkorr.    "#EC CI_SUBRC
      ENDLOOP.
    ENDIF.
*   Also read from the version table VRSD. This table contains all
*   dependent objects. For example: If from E071 a function group
*   is retrieved, VRSD will contain all functions too.
    IF re_to_add[] IS NOT INITIAL.
      SELECT korrnum, objtype, objname,
             author, datum, zeit
             FROM vrsd
             INTO (@ls_main_list_vrsd-trkorr,
                   @ls_main_list_vrsd-object,
                   @ls_main_list_vrsd-obj_name,
                   @ls_main_list_vrsd-as4user,
                   @ls_main_list_vrsd-as4date,
                   @ls_main_list_vrsd-as4time)
             FOR ALL ENTRIES IN @re_to_add
             WHERE korrnum = @re_to_add-trkorr.
        READ TABLE re_to_add
                   INTO ls_main
                   WITH KEY trkorr = ls_main_list_vrsd-trkorr.
        IF sy-subrc = 0.
          ls_main-object   = ls_main_list_vrsd-object.
          ls_main-obj_name = ls_main_list_vrsd-obj_name.
          ls_main-as4user  = ls_main_list_vrsd-as4user.
          ls_main-as4date  = ls_main_list_vrsd-as4date.
          ls_main-as4time  = ls_main_list_vrsd-as4time.
*       Only append if the object from VRSD does not already exist
*       in the main list:
          IF NOT line_exists( re_to_add[ trkorr   = ls_main-trkorr
                                         object   = ls_main-object
                                         obj_name = ls_main-obj_name ] ).
            ls_main-flag = abap_true.
            APPEND ls_main TO lt_main_list_vrsd.
          ENDIF.
        ENDIF.
      ENDSELECT.
*     Now add all VRSD entries to the main list
      APPEND LINES OF lt_main_list_vrsd TO re_to_add.
    ENDIF.
    add_table_keys_to_list( CHANGING ch_table = re_to_add ).
*   Only add the records that are not yet existing in the main list.
*   Do not add the records that already exist in the main list.
    LOOP AT re_to_add INTO ls_added.
      lp_tabix = sy-tabix.
      IF line_exists( main_list[ trkorr     = ls_added-trkorr
                                 object     = ls_added-object
                                 obj_name   = ls_added-obj_name
                                 keyobject  = ls_added-keyobject
                                 keyobjname = ls_added-keyobjname
                                 tabkey     = ls_added-tabkey ] ).
*       If the added transports are already in the list, but in prd, they
*       will be 'invisible', because the records with prd icon = co_okay
*       are filtered out. So, the prd icon needs to be changed to co_scrap
*       to become visible. Make sure that all records for this
*       transport are made visible.
        LOOP AT main_list INTO main_list_line
                         WHERE trkorr     = ls_added-trkorr
                           AND object     = ls_added-object
                           AND obj_name   = ls_added-obj_name
                           AND keyobject  = ls_added-keyobject
                           AND keyobjname = ls_added-keyobjname
                           AND tabkey     = ls_added-tabkey
                           AND prd        = co_okay.
          main_list_line-prd = co_scrap.
          MODIFY main_list FROM main_list_line
                           INDEX sy-tabix
                           TRANSPORTING prd.
        ENDLOOP.
*       No need to add this transport again:
        DELETE re_to_add INDEX lp_tabix.
      ENDIF.
    ENDLOOP.
    SORT re_to_add.
    DELETE ADJACENT DUPLICATES FROM re_to_add COMPARING ALL FIELDS.
  ENDMETHOD.

  METHOD get_additional_tp_info.
    DATA lp_counter           TYPE i.
    DATA lp_index             TYPE sytabix.
    DATA lp_indexinc          TYPE sytabix.
    DATA lp_trkorr            TYPE trkorr.
    DATA ls_main_backup       TYPE ty_request_details.
    CLEAR: lp_counter,
           total.
*   The CHECKED_BY field is always going to be filled. If it is empty,
*   then this subroutine has not yet been executed for the record, and has
*   to be executed. Additional info ONLY needs to be gathered once.
*   This needs to be checked because transports can be added. If that
*   happened, additional info only needs to be retrieved for the added
*   transports.
    LOOP AT ch_table INTO main_list_line
                    WHERE flag = abap_true.
      total = total + 1.
    ENDLOOP.
    LOOP AT ch_table INTO main_list_line
                    WHERE flag = abap_true.
*     Show the progress indicator
      IF main_list_line-prd <> co_okay.
        lp_counter = lp_counter + 1.
        progress_indicator( im_counter = lp_counter
                            im_object  = main_list_line-obj_name
                            im_total   = total
                            im_text    = 'Object data retrieved...'(010)
                            im_flag    = abap_true ).
      ENDIF.
      lp_index = sy-tabix.
*     To check next lines for same object
      lp_indexinc = lp_index + 1.
*     Only need to retrieve the additional info once, when a new transport
*     is encountered. This info is then copied to all the records (each
*     object) for the same request. So, only if the transport number is
*     different from the previous one.
      IF lp_trkorr <> main_list_line-trkorr.
        lp_trkorr = main_list_line-trkorr.

        get_additional_info( EXPORTING im_indexinc       = lp_indexinc
                             CHANGING  ch_main_list_line = main_list_line
                                       ch_table          = ch_table ).
*       Update the main table from the workarea.
        MODIFY ch_table FROM main_list_line
                        INDEX lp_index
                        TRANSPORTING checked_by
                                     status_text
                                     trfunction_txt
                                     trstatus
                                     tr_descr
                                     retcode
                                     info
                                     warning_lvl
                                     warning_txt
                                     dev
                                     qas
                                     prd
                                     as4time
                                     as4date
                                     project
                                     project_descr.
*       Keep the workarea for the other objects within the same transport.
*       No need to select the same data for each objetc because it is the
*       same for all the transport objects (data retrieved on transport
*       level).
        ls_main_backup = main_list_line.
        CONTINUE.
      ELSE.
*       Update the main table from the workarea.
        MODIFY ch_table FROM ls_main_backup
                        INDEX lp_index
                        TRANSPORTING checked_by
                                     status_text
                                     trfunction_txt
                                     trstatus
                                     tr_descr
                                     retcode
                                     info
                                     warning_lvl
                                     warning_txt
                                     dev
                                     qas
                                     prd
                                     as4time
                                     as4date
                                     project
                                     project_descr.
        CONTINUE.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_to_list.
    re_main = im_list.
*   Add the records:
    APPEND LINES OF im_to_add TO re_main.
  ENDMETHOD.

  METHOD build_conflict_popup.
    DATA lr_events          TYPE REF TO cl_salv_events_table.
    DATA ls_conflict        TYPE ty_request_details ##NEEDED.
    DATA lp_xstart          TYPE i VALUE 50.
    DATA lp_ystart          TYPE i VALUE 7.
*   Prevent the conflicts popup to be build multiple times
    IF rf_conflicts IS NOT INITIAL.
      RETURN.
    ENDIF.
*   Because we are going to only display the popup, the main list
*   does not need to be checked. So we set a flag. This makes sure
*   that all conflicting transports are added to the conflict list
*   and the main list is NOT checked again.
    set_building_conflict_popup( ).
    flag_for_process( im_rows = im_rows
                      im_cell = im_cell ).
    check_for_conflicts( CHANGING ch_main_list = main_list ).
*   If the button to add conflicts is clicked (not a double-click), then
*   remove from the popup all low-level warning messages
    IF sy-ucomm = '&ADD'.
      LOOP AT conflicts INTO ls_conflict
                        WHERE warning_rank < co_info_rank.
        DELETE conflicts INDEX sy-tabix.
      ENDLOOP.
    ENDIF.
*   Check if there are entries in the conflicts. If not, display a
*   message
    IF conflicts IS INITIAL.
      MESSAGE i000(db)
         WITH 'No transports need to be added'(019)
              'To see the conflicts, doubleclick the warning'(020).
      RETURN.
    ENDIF.
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = rf_conflicts
          CHANGING
            t_table      = conflicts ).
*       Set ALV properties
        DATA(lp_xend) = set_properties_conflicts( conflicts ).
*       Set lr_tooltips
        alv_set_lr_tooltips( rf_conflicts ).
*       Register handler for actions
        lr_events = rf_conflicts->get_event( ).
        SET HANDLER lcl_eventhandler_ztct=>on_function_click FOR lr_events.
*       Save reference to access object from handler
        lcl_eventhandler_ztct=>rf_conflicts = rf_conflicts.
*       Use gui-status ST850 from program SAPLKKB
        rf_conflicts->set_screen_status( pfstatus = 'ST850'
                                         report   = 'SAPLKKBL' ).
*       Determine the size of the popup window:
        lp_xend = lp_xend + lp_xstart + 5.
        DATA(lp_yend) = lines( conflicts ).
        IF lp_yend < 5.
          lp_yend = 5.
        ENDIF.
        lp_yend = lp_yend + lp_ystart + 1.
*       Display as popup
        rf_conflicts->set_screen_popup( start_column = lp_xstart
                                        end_column   = lp_xend
                                        start_line   = lp_ystart
                                        end_line     = lp_yend ).
        rf_conflicts->display( ).
      CATCH cx_salv_msg INTO rf_root.
        handle_error( rf_root ).
    ENDTRY.
    FREE rf_conflicts.
    set_building_conflict_popup( abap_false ).
  ENDMETHOD.

  METHOD delete_tp_from_list.
    DATA lt_range_trkorr TYPE RANGE OF trkorr.
    DATA ls_range_trkorr LIKE LINE OF lt_range_trkorr.
    DATA ls_row TYPE int4.
* If row(s) are selected, use the table
* Add transports to range
    ls_range_trkorr-sign   = 'I'.
    ls_range_trkorr-option = 'EQ'.
    LOOP AT im_rows INTO ls_row.
      READ TABLE main_list INTO main_list_line
                          INDEX ls_row.
      IF sy-subrc = 0.
        ls_range_trkorr-low = main_list_line-trkorr.
        APPEND ls_range_trkorr TO lt_range_trkorr.
      ENDIF.
    ENDLOOP.
    SORT lt_range_trkorr.
    DELETE ADJACENT DUPLICATES FROM lt_range_trkorr.
    DELETE main_list WHERE trkorr IN lt_range_trkorr.
  ENDMETHOD.

  METHOD flag_same_objects.
    DATA lt_main_list_copy TYPE ty_request_details_tt.
*   Only relevant if there is a check to be done
    IF check_flag = abap_false.
      RETURN.
    ENDIF.
*   Set check flag for all transports that are going to be refreshed
*   because all of these need to be checked again.
    lt_main_list_copy[] = ch_main_list[].
    LOOP AT ch_main_list INTO main_list_line
                         WHERE flag = abap_true.
*     Also flag all the objects already existing in the main table
*     that are in the added list: They need to be checked again.
      LOOP AT lt_main_list_copy INTO main_list_line
                               WHERE object     = main_list_line-object
                                 AND obj_name   = main_list_line-obj_name
                                 AND keyobject  = main_list_line-keyobject
                                 AND keyobjname = main_list_line-keyobjname
                                 AND tabkey     = main_list_line-tabkey
                                 AND flag = abap_false.
        main_list_line-flag = abap_true.
        MODIFY lt_main_list_copy FROM main_list_line
                                 INDEX sy-tabix
                                 TRANSPORTING flag.
      ENDLOOP.
    ENDLOOP.
    ch_main_list[] = lt_main_list_copy[].
    FREE lt_main_list_copy.

  ENDMETHOD.

  METHOD mark_all_tp_records.
    DATA lt_range_trkorr TYPE RANGE OF trkorr.
    DATA ls_range_trkorr LIKE LINE OF lt_range_trkorr.
    DATA ls_row          TYPE int4.
* Add transports to range
    ls_range_trkorr-sign   = 'I'.
    ls_range_trkorr-option = 'EQ'.
* If row(s) are selected, use the table
    LOOP AT ch_rows INTO ls_row.
      READ TABLE main_list INTO main_list_line
                           INDEX ls_row.
      IF sy-subrc = 0.
        ls_range_trkorr-low = main_list_line-trkorr.
        APPEND ls_range_trkorr TO lt_range_trkorr.
      ENDIF.
    ENDLOOP.
* If no rows were selected, take the current cell instead
    IF sy-subrc <> 0.
      READ TABLE main_list INTO main_list_line
                           INDEX im_cell-row.
      IF sy-subrc = 0.
        ls_range_trkorr-low = main_list_line-trkorr.
        APPEND ls_range_trkorr TO lt_range_trkorr.
      ENDIF.
    ENDIF.
    IF lt_range_trkorr IS INITIAL.
      RETURN.
    ENDIF.
    SORT lt_range_trkorr.
    DELETE ADJACENT DUPLICATES FROM lt_range_trkorr.
* Mark all records for all marked transports
    LOOP AT main_list INTO main_list_line
                      WHERE trkorr IN lt_range_trkorr.
      APPEND sy-tabix TO ch_rows.
    ENDLOOP.
    SORT ch_rows.
    DELETE ADJACENT DUPLICATES FROM ch_rows.
  ENDMETHOD.

  METHOD clear_flags.
    LOOP AT main_list INTO main_list_line
                      WHERE flag = abap_true.
      CLEAR main_list_line-flag.
      MODIFY main_list FROM main_list_line
                       INDEX sy-tabix
                       TRANSPORTING flag.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_filename.
    DATA lp_rc           TYPE i.
    DATA lp_desktop      TYPE string.
    DATA lt_filetable    TYPE filetable.
* Finding desktop
    cl_gui_frontend_services=>get_desktop_directory(
      CHANGING
        desktop_directory    = lp_desktop
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4 ).
    IF sy-subrc <> 0.
      MESSAGE e001(00) WITH 'Desktop not found'(008) ##MG_MISSING.
    ENDIF.
* Update View
    cl_gui_cfw=>update_view(
      EXCEPTIONS
        cntl_system_error = 1
        cntl_error        = 2
        OTHERS            = 3 ).
    DATA(lp_window_title) = |{ 'Select a transportlist'(013) }|.
    cl_gui_frontend_services=>file_open_dialog(
      EXPORTING
        window_title            = lp_window_title
        default_extension       = 'TXT'
        default_filename        = 'ZTCT_FILE'
        file_filter             = '.TXT'
        initial_directory       = lp_desktop
      CHANGING
        file_table              = lt_filetable
        rc                      = lp_rc
      EXCEPTIONS
        file_open_dialog_failed = 1
        cntl_error              = 2
        error_no_gui            = 3
        not_supported_by_gui    = 4
        OTHERS                  = 5 ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
    READ TABLE lt_filetable INDEX 1 INTO DATA(lp_file).
    IF sy-subrc = 0.
      re_file = lp_file.
    ELSE.
      re_file = 'No file selected'(061).
    ENDIF.
  ENDMETHOD.

  METHOD main_to_tab_delimited.
    DATA lp_string             TYPE string.
    DATA lp_type               TYPE char01.
    FIELD-SYMBOLS <lf_string> TYPE any.

*   Determine the number of fields in the structure
    DATA lr_tabledescr         TYPE REF TO cl_abap_tabledescr.
    DATA lr_typedescr          TYPE REF TO cl_abap_typedescr.
    DATA lr_structdescr        TYPE REF TO cl_abap_structdescr.
    DATA lt_abap_component_tab TYPE abap_component_tab.
    DATA ls_abap_component     TYPE abap_componentdescr.

    TRY.
        lr_typedescr = cl_abap_tabledescr=>describe_by_data( p_data = main_list ).
        lr_tabledescr ?= lr_typedescr.
        lr_structdescr ?= lr_tabledescr->get_table_line_type( ).
      CATCH cx_sy_move_cast_error INTO rf_root.
        handle_error( rf_root ).
      CATCH cx_root INTO rf_root ##CATCH_ALL.
        handle_error( rf_root ).
    ENDTRY.

* Build header line
    FREE re_tab_delimited.
    lt_abap_component_tab = lr_structdescr->get_components( ).
    LOOP AT lt_abap_component_tab INTO ls_abap_component.
      CONCATENATE lp_string tp_tab ls_abap_component-name INTO lp_string.
    ENDLOOP.
    SHIFT lp_string LEFT DELETING LEADING tp_tab.
    APPEND lp_string TO re_tab_delimited.
*   Now modify the lines of the main list to a tab delimited list
    LOOP AT im_main_list INTO main_list_line.
      CLEAR lp_string.
      DO.
        ASSIGN COMPONENT sy-index OF STRUCTURE main_list_line TO <lf_string>.
        IF sy-subrc <> 0.
          EXIT.
        ELSE.
          DESCRIBE FIELD <lf_string> TYPE lp_type.
          IF sy-index = 1.
            lp_string = <lf_string>.
          ELSEIF lp_type NA co_non_charlike.
            CONCATENATE lp_string tp_tab <lf_string> INTO lp_string.
          ENDIF.
        ENDIF.
      ENDDO.
      APPEND lp_string TO re_tab_delimited.
    ENDLOOP.
  ENDMETHOD.

  METHOD display_transport.
    CALL FUNCTION 'TMS_UI_SHOW_TRANSPORT_REQUEST'
      EXPORTING
        iv_request                    = im_trkorr
      EXCEPTIONS
        show_transport_request_failed = 1
        OTHERS                        = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
    LEAVE SCREEN.
  ENDMETHOD.

  METHOD display_user.
    DATA lp_return   TYPE bapiret2.
    CALL FUNCTION 'BAPI_USER_DISPLAY'
      EXPORTING
        username = im_user
      IMPORTING
        return   = lp_return.
    IF lp_return-type CA 'EA'.
      CALL FUNCTION 'SUSR_SHOW_USER_DETAILS'
        EXPORTING
          bname = im_user.
    ENDIF.
  ENDMETHOD.

  METHOD display_docu.
    DATA lp_dokl_object TYPE doku_obj.
    lp_dokl_object = im_trkorr.
    docu_call( im_object = lp_dokl_object
               im_id     = 'TA' ).
    check_documentation( EXPORTING im_trkorr = im_trkorr
                         CHANGING  ch_table  = main_list ).
  ENDMETHOD.

  METHOD refresh_alv.
*   Declaration for Top of List settings
    DATA lr_form_element TYPE REF TO cl_salv_form_element.

    lr_form_element = top_of_page( ).
    rf_table->set_top_of_list( lr_form_element ).
    set_color( ).
    alv_set_lr_tooltips( rf_table ).
    rf_table->refresh( ).
  ENDMETHOD.

  METHOD tab_delimited_to_main.
    TYPES: BEGIN OF ty_upl_line,
             field TYPE fieldname,
             value TYPE string,
           END OF ty_upl_line.
    DATA lt_items              TYPE TABLE OF ty_upl_line.
    DATA ls_item               TYPE ty_upl_line.
    DATA lt_main_upl           TYPE ty_request_details_tt.
    DATA ls_main_line_upl      TYPE ty_request_details.
    DATA ls_main               TYPE ty_request_details.
    DATA lp_type               TYPE char01.
    FIELD-SYMBOLS <lf_string>  TYPE any.
*   Determine the number of fields in the structure
    DATA lr_o_tabledescr       TYPE REF TO cl_abap_tabledescr.
    DATA lr_o_typedescr        TYPE REF TO cl_abap_typedescr.
    DATA lr_o_structdescr      TYPE REF TO cl_abap_structdescr.
    DATA ls_component          TYPE abap_compdescr.
    TRY.
        lr_o_typedescr = cl_abap_tabledescr=>describe_by_data( p_data = main_list ).
        lr_o_tabledescr ?= lr_o_typedescr.
        lr_o_structdescr ?= lr_o_tabledescr->get_table_line_type( ).
      CATCH cx_sy_move_cast_error INTO rf_root.
        handle_error( rf_root ).
      CATCH cx_root INTO rf_root ##CATCH_ALL.
        handle_error( rf_root ).
    ENDTRY.
*   First line contains the name of the fields
*   Now modify the lines of the main list to a tab delimited list
    READ TABLE im_tab_delimited INDEX 1
                                INTO DATA(lp_header).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
*   Build list of fields, in order of uploaded file
    DO.
      SPLIT lp_header AT tp_tab INTO ls_item-field lp_header.
      IF ls_item-field IS INITIAL.
        EXIT.
      ENDIF.
      APPEND ls_item TO lt_items.
    ENDDO.
*   Skip the header line, start at line 2
    LOOP AT im_tab_delimited FROM 2
                             INTO lp_header.
      CLEAR ls_item.
*     First put all values for this record in the value table
*     Build list of fields, in order of uploaded file
      DO.
*       Get the corresponding line from the table containing
*       the fields and values (to be updated with the value)
        READ TABLE lt_items INDEX sy-index
                            INTO ls_item.
        IF sy-subrc <> 0.
          EXIT.
        ELSE.
          SPLIT lp_header AT tp_tab INTO ls_item-value lp_header.
          MODIFY lt_items FROM ls_item
                          INDEX sy-tabix
                          TRANSPORTING value.
        ENDIF.
      ENDDO.
*     Map the fields from the uploaded line to the correct component
*     of the main list
      DO.
*       Get corresponding fieldname for file column
        READ TABLE lt_items INTO ls_item
                            INDEX sy-index.
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.
*       Get information about where the column is in the structure
*       Get the lenght and position from the structure definition:
        READ TABLE lr_o_structdescr->components
                   INTO ls_component
                   WITH KEY name = ls_item-field.
        IF sy-subrc = 0.
          ASSIGN COMPONENT ls_component-name OF STRUCTURE ls_main_line_upl TO <lf_string>.
          IF sy-subrc <> 0.
            EXIT.
          ELSE.
            DESCRIBE FIELD <lf_string> TYPE lp_type.
            IF lp_type NA co_non_charlike.
              TRY.
                  <lf_string> = ls_item-value.
                CATCH cx_root INTO rf_root  ##CATCH_ALL ##NO_HANDLER.
              ENDTRY.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDDO.
      APPEND ls_main_line_upl TO lt_main_upl.
      CLEAR ls_main_line_upl.
    ENDLOOP.

*   Now move the lines of the uploaded list to the main list and
*   if another file is added to the main list (&ADD_FILE), then
*   Automatically RE-Check the objects in the existing main list
    total = lines( lt_main_upl ).
    LOOP AT lt_main_upl INTO ls_main.
      progress_indicator( im_counter = sy-tabix
                          im_object  = ''
                          im_total   = total
                          im_text    = 'records read and added.'(022)
                          im_flag    = abap_true ).
*     Check if the record is already in the main list:
      IF NOT line_exists( main_list[ trkorr     = ls_main-trkorr
                                     object     = ls_main-object
                                     obj_name   = ls_main-obj_name
                                     keyobject  = ls_main-keyobject
                                     keyobjname = ls_main-keyobjname
                                     tabkey     = ls_main-tabkey ] ).
*       If a file is uploaded to be merged (&ADD_FILE), then we need to
*       check all the records that are going to be added to the main list,
*       as well as all the records in the main list that contain an object
*       also in the loaded list:
        IF sy-ucomm  = '&ADD_FILE'.
          ls_main-flag = abap_true.
          LOOP AT main_list ASSIGNING FIELD-SYMBOL(<lf_main_list_line>)
                           WHERE object     = ls_main-object
                             AND obj_name   = ls_main-obj_name
                             AND keyobject  = ls_main-keyobject
                             AND keyobjname = ls_main-keyobjname
                             AND tabkey     = ls_main-tabkey.
            <lf_main_list_line>-flag = abap_true.
          ENDLOOP.
        ENDIF.
        APPEND ls_main TO main_list.
      ENDIF.
    ENDLOOP.
    sort_list( CHANGING ch_list = main_list ).
  ENDMETHOD.

  METHOD gui_upload.
    DATA lt_tab_delimited TYPE table_of_strings.
    DATA lt_temp_table    TYPE table_of_strings.
    CLEAR re_cancelled.
    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = im_filename
        filetype                = 'ASC'
      CHANGING
        data_tab                = lt_temp_table
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        unknown_error           = 7
        bad_data_format         = 8
        header_not_allowed      = 9
        separator_not_allowed   = 10
        header_too_long         = 11
        unknown_dp_error        = 12
        access_denied           = 13
        dp_out_of_memory        = 14
        disk_full               = 15
        dp_timeout              = 16
        not_supported_by_gui    = 17
        error_no_gui            = 18
        OTHERS                  = 19 ).
    IF sy-subrc <> 0.
      re_cancelled = abap_true.
      CASE sy-subrc.
        WHEN 1.
          IF im_filename IS INITIAL.
            MESSAGE i000(db) WITH 'Cancelled by user'(031).
          ELSE.
            MESSAGE i000(db) DISPLAY LIKE 'E' WITH 'Error occurred'(029).
          ENDIF.
        WHEN OTHERS.
          MESSAGE i000(db) DISPLAY LIKE 'E' WITH 'Error occurred'(029).
      ENDCASE.
    ELSE.
      lt_tab_delimited[] = lt_temp_table[].
*     Now convert the tab delimited file to the main list field order:
      tab_delimited_to_main( lt_tab_delimited ).
      total = lines( main_list ).
*     Always reset the Check flag when uploading. Reason is that
*     when combining multiple ZTCT files, these SHOULD be corrected
*     already. First ythe user collects and combines ALL the files.
*     When all files have been combined/uploaded, the user can use
*     the RECHECK button to do a final check on all transports.
      clear_flags( ).
      LOOP AT main_list INTO main_list_line.
        progress_indicator( im_counter = sy-tabix
                            im_object  = main_list_line-obj_name
                            im_total   = total
                            im_text    = 'records checked (documentation)'(023)
                            im_flag    = abap_true ).
        check_documentation( EXPORTING im_trkorr = main_list_line-trkorr
                             CHANGING  ch_table  = main_list ).
      ENDLOOP.
    ENDIF.
*   A simple check on the internal table. If a warning is found, then
*   we assume that the check parameter needs to be switched ON.
    LOOP AT main_list INTO main_list_line
                      WHERE warning_lvl IS NOT INITIAL.
      set_check_flag( ).
      EXIT.
    ENDLOOP.
*   Check if the Checked icon needs to be cleared:
    IF clear_checked = abap_true.
      LOOP AT main_list INTO main_list_line
                        WHERE checked = co_checked.
        CLEAR main_list_line-checked.
        MODIFY main_list FROM main_list_line
                         INDEX sy-tabix
                         TRANSPORTING checked.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD check_if_in_list.
    CLEAR re_line.
* This subroutine checks if the conflicting transport/object is found
* further down in the list (in a later transport):
    DATA(lp_tabix) = im_tabix + 1.
    LOOP AT main_list INTO re_line FROM lp_tabix
                     WHERE trkorr     = im_line-trkorr
                       AND object     = im_line-object
                       AND obj_name   = im_line-obj_name
                       AND keyobject  = im_line-keyobject
                       AND keyobjname = im_line-keyobjname
                       AND tabkey     = im_line-tabkey
                       AND prd        <> co_okay.
      EXIT.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_newer_transports.
    DATA lt_stms_wbo_requests TYPE TABLE OF stms_wbo_request.
    DATA ls_stms_wbo_requests TYPE stms_wbo_request.
    DATA lp_tabix             TYPE sytabix.
    DATA lp_return            TYPE c.
    DATA ls_line_temp         TYPE ty_request_details.
    DATA ls_newer_line        TYPE ty_request_details.
    DATA lt_e07t              TYPE e07t_t.
    DATA ls_e07t              TYPE e07t.
    DATA lp_target            TYPE tmssysnam.

    DATA(lp_exit) = abap_false.

    FREE lt_e07t.

*   The check is only relevant if transport is in QAS or DEV! Check is
*   skipped for the transports, already in prd.
    IF ch_main-qas = co_okay.
      lp_target = prd_system.
    ENDIF.

    IF im_newer_transports[] IS NOT INITIAL.
      SELECT trkorr, langu, as4text
             FROM e07t INTO CORRESPONDING FIELDS OF TABLE @lt_e07t
             FOR ALL ENTRIES IN @im_newer_transports
             WHERE trkorr = @im_newer_transports-trkorr
             ORDER BY PRIMARY KEY.                        "#EC CI_SUBRC
    ENDIF.
    LOOP AT im_newer_transports INTO ls_newer_line.
*     Get transport description
      READ TABLE lt_e07t INTO ls_e07t
                     WITH KEY trkorr = ls_newer_line-trkorr.
      IF sy-subrc = 0.
        ls_newer_line-tr_descr = ls_e07t-as4text.
      ENDIF.
*     Check if it has been transported to the target system
      FREE lt_stms_wbo_requests.
      CLEAR lt_stms_wbo_requests.
      READ TABLE tms_mgr_buffer INTO tms_mgr_buffer_line
           WITH TABLE KEY request          = ls_newer_line-trkorr
                          target_system    = lp_target.
      IF sy-subrc = 0.
        lt_stms_wbo_requests = tms_mgr_buffer_line-request_infos.
      ELSE.
        CALL FUNCTION 'TMS_MGR_READ_TRANSPORT_REQUEST'
          EXPORTING
            iv_request                 = ls_newer_line-trkorr
            iv_target_system           = lp_target
            iv_header_only             = 'X'
            iv_monitor                 = ' '
          IMPORTING
            et_request_infos           = lt_stms_wbo_requests
          EXCEPTIONS
            read_config_failed         = 1
            table_of_requests_is_empty = 2
            system_not_available       = 3
            OTHERS                     = 4.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                  WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ELSE.
          tms_mgr_buffer_line-request       = ls_newer_line-trkorr.
          tms_mgr_buffer_line-target_system = lp_target.
          tms_mgr_buffer_line-request_infos = lt_stms_wbo_requests.
          INSERT tms_mgr_buffer_line INTO TABLE tms_mgr_buffer.
        ENDIF.
      ENDIF.
      READ TABLE lt_stms_wbo_requests INDEX 1
                 INTO ls_stms_wbo_requests.
      IF sy-subrc = 0 AND ls_stms_wbo_requests-e070 IS NOT INITIAL.
*       Only display the warning if the preceding transport is not
*       one of the selected transports (and in an earlier
*       position)
        check_if_same_object( EXPORTING im_line        = ch_main
                                        im_newer_older = ls_newer_line
                              IMPORTING ex_tabkey      = tp_tabkey
                                        ex_return      = lp_return ).
        CHECK lp_return = abap_true.
*       Fill conflict list
        conflict_line = CORRESPONDING #( ls_newer_line ).
        conflict_line-warning_lvl  = co_error.
        conflict_line-warning_rank = co_error_rank.
        conflict_line-warning_txt  = lp_error_text.
        conflict_line-objkey       = tp_tabkey.
*       Get the last date the object was imported
        get_import_datetime_qas( EXPORTING im_trkorr  = ls_newer_line-trkorr
                                 IMPORTING ex_as4time = conflict_line-as4time
                                           ex_as4date = conflict_line-as4date ).
*       Check if the transport is in the list
*       Display the warning if the preceding transport is not
*       in the main list. If it is, then display the hint icon.
        READ TABLE im_main_list
              INTO ls_line_temp
              WITH KEY trkorr = ls_newer_line-trkorr
              TRANSPORTING prd.
        IF sy-subrc = 0.
          IF ls_line_temp-prd = co_scrap.
*           This newer version is in the list and made visible:
            conflict_line-warning_lvl = co_scrap.
          ENDIF.
        ELSE.
          APPEND conflict_line TO conflicts.
          CLEAR conflict_line.
        ENDIF.
      ELSE.
        line_found_in_list = check_if_in_list( im_line  = ls_newer_line
                                               im_tabix = lp_tabix ).
        IF line_found_in_list IS NOT INITIAL.
*         Even if the transport is only in QAS and not in prd (so a
*         newer transport exists, but will not be overwritten), we still
*         want to let the user now about it. To prevent that a newer
*         development exists and should go to production, but it might
*         be forgotten if not selected...
          ch_main-warning_lvl        = co_hint.
          ls_newer_line-warning_lvl  = co_hint.
          ch_main-warning_rank       = co_hint2_rank.
          ls_newer_line-warning_rank = co_hint2_rank.
          ch_main-warning_txt        = lp_hint2_text.
          ls_newer_line-warning_txt  = lp_hint2_text.
*         No need to check further. A newer transport was found but because
*         that newer transport is in the list, we can stop checking for newer
*         transports because that will be done for the transport that is in
*         the list.
          lp_exit = abap_true.
        ELSE.
*         The transport is not yet transported, but if it is found
*         further down in the list, it is okay. Change the warning level
*         from ERROR to INFO.
          ch_main-warning_lvl        = co_info.
          ls_newer_line-warning_lvl  = co_info.
          ch_main-warning_rank       = co_info_rank.
          ls_newer_line-warning_rank = co_info_rank.
          ch_main-warning_txt        = lp_info_text.
          ls_newer_line-warning_txt  = lp_info_text.
        ENDIF.
        conflict_line = CORRESPONDING #( ls_newer_line ).
        APPEND conflict_line TO conflicts.
        CLEAR conflict_line.
        IF lp_exit = abap_true.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.
    ch_conflicts = conflicts.
  ENDMETHOD.

  METHOD check_older_transports.
    DATA lt_stms_wbo_requests TYPE TABLE OF stms_wbo_request.
    DATA ls_stms_wbo_requests TYPE stms_wbo_request.
    DATA lp_return            TYPE c.
    DATA ls_older_line        TYPE ty_request_details.
    DATA lt_e07t              TYPE e07t_t.
    DATA ls_e07t              TYPE e07t.
    DATA lp_target            TYPE tmssysnam.

    FREE lt_e07t.

*   The check is only relevant if transport is in QAS or DEV! Check is
*   skipped for the transports, already in prd.
    IF ch_main-qas = co_okay.
      lp_target = prd_system.
    ENDIF.

    IF im_older_transports[] IS NOT INITIAL.
      SELECT trkorr, langu, as4text
             FROM e07t INTO CORRESPONDING FIELDS OF TABLE @lt_e07t
             FOR ALL ENTRIES IN @im_older_transports
             WHERE trkorr = @im_older_transports-trkorr
             ORDER BY PRIMARY KEY.                        "#EC CI_SUBRC
    ENDIF.
    LOOP AT im_older_transports INTO ls_older_line.
*     Get transport description
      READ TABLE lt_e07t INTO ls_e07t
                     WITH KEY trkorr = ls_older_line-trkorr.
      IF sy-subrc = 0.
        ls_older_line-tr_descr = ls_e07t-as4text.
      ENDIF.
*     Check if it has been transported to QAS
      FREE lt_stms_wbo_requests.
      CLEAR lt_stms_wbo_requests.
      READ TABLE tms_mgr_buffer INTO tms_mgr_buffer_line
                      WITH TABLE KEY request          = ls_older_line-trkorr
                                     target_system    = lp_target.
      IF sy-subrc = 0.
        lt_stms_wbo_requests = tms_mgr_buffer_line-request_infos.
      ELSE.
        CALL FUNCTION 'TMS_MGR_READ_TRANSPORT_REQUEST'
          EXPORTING
            iv_request                 = ls_older_line-trkorr
            iv_target_system           = lp_target
            iv_header_only             = 'X'
            iv_monitor                 = ' '
          IMPORTING
            et_request_infos           = lt_stms_wbo_requests
          EXCEPTIONS
            read_config_failed         = 1
            table_of_requests_is_empty = 2
            system_not_available       = 3
            OTHERS                     = 4.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                  WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ELSE.
          tms_mgr_buffer_line-request       = ls_older_line-trkorr.
          tms_mgr_buffer_line-target_system = lp_target.
          tms_mgr_buffer_line-request_infos = lt_stms_wbo_requests.
          INSERT tms_mgr_buffer_line INTO TABLE tms_mgr_buffer.
        ENDIF.
      ENDIF.
*     Was an older transport found that has not yet gone to EEP?
      READ TABLE lt_stms_wbo_requests INDEX 1
                                      INTO ls_stms_wbo_requests.
      IF sy-subrc = 0 AND ls_stms_wbo_requests-e070 IS INITIAL.
        check_if_same_object( EXPORTING im_line        = ch_main
                                        im_newer_older = ls_older_line
                              IMPORTING ex_tabkey      = tp_tabkey
                                        ex_return      = lp_return ).
*       Yes, same object!
        IF lp_return = abap_true.
          conflict_line = CORRESPONDING #( ls_older_line ).
*         Get the last date the object was imported
          get_import_datetime_qas( EXPORTING im_trkorr  = ls_older_line-trkorr
                                   IMPORTING ex_as4time = conflict_line-as4time
                                             ex_as4date = conflict_line-as4date ).
          conflict_line-warning_lvl  = co_warn.
          conflict_line-warning_rank = co_warn_rank.
          main_list_line-warning_txt = lp_warn_text.
          conflict_line-objkey       = tp_tabkey.
*         Check if the transport is in the list
*         Display the warning if the preceding transport is not
*         in the main list. If it is, then display the hint icon.
          IF line_exists( im_main_list[ trkorr = ls_older_line-trkorr ] ).
*           There is a warning but the conflicting transport is
*           ALSO in the list. Display the HINT Icon. The other
*           transport will be checked too, sooner or later...
            conflict_line-warning_lvl  = co_hint.
            conflict_line-warning_rank = co_hint2_rank.
            conflict_line-warning_txt  = lp_hint2_text.
          ENDIF.
*         Check if transport has been released.
*         D - Modifiable
*         L - Modifiable, protected
*         A - Modifiable, protected
*         O - Release started
*         R - Released
*         N - Released (with import protection for repaired objects)
          FREE lt_stms_wbo_requests.
          CLEAR lt_stms_wbo_requests.
          READ TABLE tms_mgr_buffer INTO tms_mgr_buffer_line
                          WITH TABLE KEY request          = ls_older_line-trkorr
                                         target_system    = dev_system.
          IF sy-subrc = 0.
            lt_stms_wbo_requests = tms_mgr_buffer_line-request_infos.
          ELSE.
            CALL FUNCTION 'TMS_MGR_READ_TRANSPORT_REQUEST'
              EXPORTING
                iv_request                 = ls_older_line-trkorr
                iv_target_system           = dev_system
                iv_header_only             = 'X'
                iv_monitor                 = ' '
              IMPORTING
                et_request_infos           = lt_stms_wbo_requests
              EXCEPTIONS
                read_config_failed         = 1
                table_of_requests_is_empty = 2
                system_not_available       = 3
                OTHERS                     = 4.
            IF sy-subrc <> 0.
              MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
            ELSE.
              tms_mgr_buffer_line-request       = ls_older_line-trkorr.
              tms_mgr_buffer_line-target_system = lp_target.
              tms_mgr_buffer_line-request_infos = lt_stms_wbo_requests.
              INSERT tms_mgr_buffer_line INTO TABLE tms_mgr_buffer.
            ENDIF.
          ENDIF.
          READ TABLE lt_stms_wbo_requests INDEX 1
                                          INTO ls_stms_wbo_requests.
          IF sy-subrc = 0.
            IF ls_stms_wbo_requests-e070-trstatus NA 'NR'.
              conflict_line-warning_lvl  = co_alert.
              conflict_line-warning_rank = co_alert1_rank.
              conflict_line-warning_txt  = lp_alert1_text.
            ELSEIF ls_stms_wbo_requests-e070-trstatus = 'O'.
              conflict_line-warning_lvl  = co_alert.
              conflict_line-warning_rank = co_alert2_rank.
              conflict_line-warning_txt  = lp_alert2_text.
            ENDIF.
          ENDIF.
          IF conflict_line IS NOT INITIAL.
            APPEND conflict_line TO conflicts.
            CLEAR conflict_line.
          ENDIF.
        ENDIF.
      ELSE.
*       When the first earlier transported version is found,
*       the check must be ended.
        EXIT.
      ENDIF.
    ENDLOOP.
    ch_conflicts = conflicts.
  ENDMETHOD.

  METHOD check_if_same_object.
*   Although there is already a warning (older transport not moved or
*   newer transport was moved), it must be the exact same object. If it's
*   an entry in a table, it should not be checked if the table was
*   changed, but if it's the same entry that was changed... This perform
*   check the key entries.
    DATA ls_e071k TYPE e071k.
    CLEAR: ex_tabkey,
           ex_return.
*   The check on object (if the same) can either be done on key level (for
*   tables) or just on object level... Depends on the OBJFUNC field.
    CASE im_line-objfunc.
      WHEN 'K'.
*       Key fields available
        SELECT SINGLE tabkey, objname
                 FROM e071k
                 INTO CORRESPONDING FIELDS OF @ls_e071k
                WHERE trkorr = @im_newer_older-trkorr
                  AND tabkey = @im_line-tabkey.           "#EC CI_SUBRC
*       Now check if in both transports an object exists with the
*       same key
        IF ls_e071k IS INITIAL.
*         No key found. Treat as if it's the same object...
          IF im_newer_older-object = im_line-object
              AND im_newer_older-obj_name = im_line-obj_name.
            ex_return = abap_true.
          ENDIF.
        ELSE.
*         There are records to be compared, only if the record is for the
*         same key, accept the warning as true (return = 'X').
          ex_return = abap_true.
          CONCATENATE ls_e071k-tabkey ' ('
                      ls_e071k-objname ')'
                      INTO ex_tabkey.
        ENDIF.
      WHEN OTHERS.
        IF im_newer_older-object = im_line-object
            AND im_newer_older-obj_name = im_line-obj_name.
          ex_return = abap_true.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD check_documentation.
*   Documentation - text lines
    DATA ls_doktl  TYPE doktl.
    tp_dokl_object = im_trkorr.
    SELECT SINGLE id, object
             FROM doktl
             INTO CORRESPONDING FIELDS OF @ls_doktl
            WHERE id        = 'TA'
              AND object    = @tp_dokl_object
              AND typ       = 'T'
              AND dokformat <> 'L'
              AND doktext   <> ''.                        "#EC CI_SUBRC
    IF sy-subrc = 0.
*     There is documentation: Display Doc Icon
      main_list_line-info = co_docu.
    ELSE.
*     There is no documentation: Remove Doc Icon
      CLEAR main_list_line-info.
    ENDIF.
    MODIFY ch_table FROM main_list_line
                    TRANSPORTING info
                    WHERE trkorr = im_trkorr.
  ENDMETHOD.

  METHOD alv_init.
    CLEAR rf_table.
    TRY.
        cl_salv_table=>factory(
          EXPORTING
            list_display = if_salv_c_bool_sap=>false
          IMPORTING
            r_salv_table = rf_table
          CHANGING
            t_table      = main_list ).
      CATCH cx_salv_msg INTO rf_root.
        handle_error( rf_root ).
    ENDTRY.
    IF rf_table IS INITIAL.
      MESSAGE 'Error Creating ALV Grid'(t03) TYPE 'A' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD alv_xls_init.
    TRY.
        cl_salv_table=>factory(
          EXPORTING
            list_display = if_salv_c_bool_sap=>false
          IMPORTING
            r_salv_table = ex_rf_table
          CHANGING
            t_table      = ch_table ).
      CATCH cx_salv_msg INTO rf_root.
        handle_error( rf_root ).
    ENDTRY.
    IF rf_table_xls IS INITIAL.
      MESSAGE 'Error Creating ALV Grid'(t03) TYPE 'A' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD set_color.
*   Color Structure of columns
    DATA lt_scol                     TYPE lvc_t_scol.
    DATA ls_scol                     TYPE lvc_s_scol.

    LOOP AT main_list ASSIGNING FIELD-SYMBOL(<lf_main>).
*     Init
      FREE lt_scol.
      CLEAR ls_scol.
      <lf_main>-t_color = lt_scol.
*     Add color
      IF <lf_main>-warning_rank >= co_info_rank.
        FREE lt_scol.
        CLEAR ls_scol.
        ls_scol-color-col = 3.
        ls_scol-color-int = 0.
        ls_scol-color-inv = 0.
        ls_scol-fname     = 'WARNING_TXT'.
        APPEND ls_scol TO lt_scol.
        ls_scol-fname     = 'WARNING_LVL'.
        APPEND ls_scol TO lt_scol.
        <lf_main>-t_color = lt_scol.
      ENDIF.
      IF <lf_main>-warning_rank >= co_warn_rank.
        FREE lt_scol.
        CLEAR ls_scol.
        ls_scol-color-col = 7.
        ls_scol-color-int = 0.
        ls_scol-color-inv = 0.
        ls_scol-fname     = 'WARNING_TXT'.
        APPEND ls_scol TO lt_scol.
        ls_scol-fname     = 'WARNING_LVL'.
        APPEND ls_scol TO lt_scol.
        <lf_main>-t_color = lt_scol.
      ENDIF.
      IF <lf_main>-warning_rank >= co_error_rank.
        FREE lt_scol.
        CLEAR ls_scol.
        ls_scol-color-col = 6.
        ls_scol-color-int = 0.
        ls_scol-color-inv = 0.
        ls_scol-fname     = 'WARNING_TXT'.
        APPEND ls_scol TO lt_scol.
        ls_scol-fname     = 'WARNING_LVL'.
        APPEND ls_scol TO lt_scol.
        <lf_main>-t_color = lt_scol.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD set_check_flag.
    IF im_check_flag IS SUPPLIED.
      check_flag = im_check_flag.
    ELSE.
      check_flag = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD set_check_tabkeys.
    IF im_check_tabkeys IS SUPPLIED.
      check_tabkeys = im_check_tabkeys.
    ELSE.
      check_tabkeys = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD set_clear_checked.
    IF im_clear_checked IS SUPPLIED.
      clear_checked = im_clear_checked.
    ELSE.
      clear_checked = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD set_buffer_chk.
    IF im_buffer_chk IS SUPPLIED.
      buffer_chk = im_buffer_chk.
    ELSE.
      buffer_chk = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD set_buffer_remove_tp.
    IF im_buffer_remove_tp IS SUPPLIED.
      buffer_remove_tp = im_buffer_remove_tp.
    ELSE.
      buffer_remove_tp = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD set_trkorr_range.
    trkorr_range = im_trkorr_range.
  ENDMETHOD.

  METHOD set_project_range.
    project_range = im_project_range.
  ENDMETHOD.

  METHOD set_excluded_objects.
    excluded_objects = im_excluded_objects.
  ENDMETHOD.

  METHOD set_user_layout.
    user_layout = im_user_layout.
  ENDMETHOD.

  METHOD set_process_type.
    process_type = im_process_type.
  ENDMETHOD.

  METHOD set_skiplive.
    IF im_skiplive IS SUPPLIED.
      skiplive = im_skiplive.
    ELSE.
      skiplive = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD set_filename.
    filename = im_filename.
  ENDMETHOD.

  METHOD set_systems.
    dev_system = im_dev_system.
    qas_system = im_qas_system.
    prd_system = im_prd_system.
*   Move to range:
    APPEND INITIAL LINE TO systems_range ASSIGNING FIELD-SYMBOL(<lf_system_range>).
    <lf_system_range>-sign   = 'I'.
    <lf_system_range>-option = 'EQ'.
    <lf_system_range>-low    = dev_system.
    APPEND INITIAL LINE TO systems_range ASSIGNING <lf_system_range>.
    <lf_system_range>-sign   = 'I'.
    <lf_system_range>-option = 'EQ'.
    <lf_system_range>-low    = qas_system.
    APPEND INITIAL LINE TO systems_range ASSIGNING <lf_system_range>.
    <lf_system_range>-sign   = 'I'.
    <lf_system_range>-option = 'EQ'.
    <lf_system_range>-low    = prd_system.
  ENDMETHOD.

  METHOD set_building_conflict_popup.
    IF im_building_conflict_popup IS SUPPLIED.
      building_conflict_popup = im_building_conflict_popup.
    ELSE.
      building_conflict_popup = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD alv_set_properties.
*   Declaration for ALV Columns
    DATA lr_columns_table       TYPE REF TO cl_salv_columns_table.
    DATA lt_t_column_ref        TYPE salv_t_column_ref.
    DATA lr_functions_list      TYPE REF TO cl_salv_functions_list.
*   Declaration for Layout Settings
    DATA lr_layout              TYPE REF TO cl_salv_layout.
    DATA ls_layout_key          TYPE salv_s_layout_key.
*   Declaration for Aggregate Function Settings
    DATA lr_aggregations        TYPE REF TO cl_salv_aggregations ##NEEDED.
*   Declaration for Sort Function Settings
    DATA lr_sorts               TYPE REF TO cl_salv_sorts.
*   Declaration for Table Selection settings
    DATA lr_selections          TYPE REF TO cl_salv_selections.
*   Declaration for Global Display Settings
    DATA lr_display_settings    TYPE REF TO cl_salv_display_settings.
    DATA lp_class               TYPE xuclass.
    DATA lp_accnt               TYPE xuaccnt.

    CONSTANTS: lc_class TYPE xuclass VALUE 'NLD_T_040',
               lc_accnt TYPE xuaccnt VALUE 'I210218 0079'.

    ASSIGN im_table TO FIELD-SYMBOL(<lf_table>).
    IF <lf_table> IS NOT ASSIGNED.
      RETURN.
    ENDIF.
*   Set status
*   Copy the status from program SAPLSLVC_FULLSCREEN and delete the
*   buttons you do not need. Add extra buttons for use in USER_COMMAND
    <lf_table>->set_screen_status( pfstatus = 'STANDARD_FULLSCREEN'
                                   report   = sy-repid ).
*   Get functions details
    lr_functions_list = <lf_table>->get_functions( ).
*   Activate All Buttons in Tool Bar
    lr_functions_list->set_all( if_salv_c_bool_sap=>true ).
*   If necessary, deactivate functions
    IF check_flag = abap_false.
      TRY.
          lr_functions_list->set_function( name    = 'RECHECK'
                                           boolean = if_salv_c_bool_sap=>false ).
        CATCH cx_root INTO rf_root ##CATCH_ALL.
          handle_error( rf_root ).
      ENDTRY.
    ENDIF.
*   Layout Settings
    CLEAR lr_layout.
    CLEAR ls_layout_key.
*   Set Report ID as Layout Key
    ls_layout_key-report = sy-repid.
*   Get Layout of Table
    lr_layout = <lf_table>->get_layout( ).
*   To allow DEFAULT layout
    lr_layout->set_default( if_salv_c_bool_sap=>true ).
*   Set Report Id to Layout
    lr_layout->set_key( ls_layout_key ).
*   If the user is part of a specific class, then the user can
*   maintain all layouts. Otherwise only the user specific layout.
    SELECT SINGLE class, accnt
                  FROM usr02
                  INTO (@lp_class,
                        @lp_accnt)
                 WHERE bname = @sy-uname.
*   Hardcoded: Change this to allow certain group of users to change
*   the default layout for all users
    IF sy-subrc = 0 AND lp_class = lc_class AND lp_accnt = lc_accnt.
      lp_save_restriction = if_salv_c_layout=>restrict_none.
    ELSE.
      lp_save_restriction = if_salv_c_layout=>restrict_user_dependant.
    ENDIF.
*   If the flag is set the default layout will be the default user
*   specific layout
    IF user_layout = abap_false.
      lr_layout->set_initial_layout( '/DEFAULT' ).
    ENDIF.

    lr_layout->set_save_restriction( lp_save_restriction ).
*   Global Display Settings
    CLEAR: lr_display_settings.
*   Global display settings
    lr_display_settings = <lf_table>->get_display_settings( ).
*   Activate Striped Pattern
    lr_display_settings->set_striped_pattern( if_salv_c_bool_sap=>true ).
*   Report header
    lr_display_settings->set_list_header( sy-title ).
*   Aggregate Function Settings
    lr_aggregations = <lf_table>->get_aggregations( ).
*   Sort Functions
    lr_sorts = <lf_table>->get_sorts( ).
    IF lr_sorts IS NOT INITIAL.
      TRY.
          lr_sorts->add_sort( columnname = 'AS4DATE'
                              position   = 1
                              sequence   = if_salv_c_sort=>sort_up
                              subtotal   = if_salv_c_bool_sap=>false
                              obligatory = if_salv_c_bool_sap=>false ).
        CATCH cx_salv_not_found INTO rf_root.
          handle_error( rf_root ).
        CATCH cx_salv_existing INTO rf_root.
          handle_error( rf_root ).
        CATCH cx_salv_data_error INTO rf_root.
          handle_error( rf_root ).
      ENDTRY.
      TRY.
          lr_sorts->add_sort( columnname = 'AS4TIME'
                              position   = 2
                              sequence   = if_salv_c_sort=>sort_up
                              subtotal   = if_salv_c_bool_sap=>false
                              group      = if_salv_c_sort=>group_none
                              obligatory = if_salv_c_bool_sap=>false ).
        CATCH cx_salv_not_found INTO rf_root.
          handle_error( rf_root ).
        CATCH cx_salv_existing INTO rf_root.
          handle_error( rf_root ).
        CATCH cx_salv_data_error INTO rf_root.
          handle_error( rf_root ).
      ENDTRY.
    ENDIF.
*   Table Selection Settings
    lr_selections = <lf_table>->get_selections( ).
    IF lr_selections IS NOT INITIAL.
*   Allow row Selection
      lr_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).
    ENDIF.
*   Event Register settings
    rf_events_table = <lf_table>->get_event( ).
    rf_handle_events = NEW #( ).
    SET HANDLER lcl_eventhandler_ztct=>on_function_click FOR rf_events_table.
    SET HANDLER lcl_eventhandler_ztct=>on_double_click   FOR rf_events_table.
    SET HANDLER lcl_eventhandler_ztct=>on_link_click     FOR rf_events_table.
*   Get the columns from ALV Table
    lr_columns_table = <lf_table>->get_columns( ).
    IF lr_columns_table IS NOT INITIAL.
      FREE lt_t_column_ref.
      lt_t_column_ref = lr_columns_table->get( ).
*     Get columns properties
      lr_columns_table->set_optimize( if_salv_c_bool_sap=>true ).
      lr_columns_table->set_key_fixation( if_salv_c_bool_sap=>true ).
      TRY.
          lr_columns_table->set_color_column( 'T_COLOR' ).
        CATCH cx_salv_data_error INTO rf_root.
          handle_error( rf_root ).
      ENDTRY.
*     Individual Column Properties.
      column_settings( im_column_ref       = lt_t_column_ref
                       im_rf_columns_table = lr_columns_table
                       im_table            = <lf_table> ).
    ENDIF.
  ENDMETHOD.

  METHOD alv_set_lr_tooltips.
*   Fill the symbols, colors in to table and set lr_tooltips
    DATA lr_tooltips TYPE REF TO cl_salv_tooltips.
    DATA lr_settings TYPE REF TO cl_salv_functional_settings.
    DATA lp_text  TYPE lvc_tip.
    FREE lr_settings.
    FREE lr_tooltips.
    lr_settings = im_table->get_functional_settings( ).
    lr_tooltips = lr_settings->get_tooltips( ).
    TRY.
        lp_text = 'Newer version in test environment'(w23).
        lr_tooltips->add_tooltip( type    = cl_salv_tooltip=>c_type_symbol
                                  value   = '@AH@'
                                  tooltip = lp_text ).
      CATCH cx_salv_existing INTO rf_root ##NO_HANDLER.
    ENDTRY.
    TRY.
        lp_text = 'Previous transport not transported'(w17).
        lr_tooltips->add_tooltip( type    = cl_salv_tooltip=>c_type_symbol
                                  value   = '@5D@'
                                  tooltip = lp_text ).
      CATCH cx_salv_existing INTO rf_root ##NO_HANDLER.
    ENDTRY.
    TRY.
        lp_text = 'Conflicts are dealt with'(w04).
        lr_tooltips->add_tooltip( type    = cl_salv_tooltip=>c_type_symbol
                                  value   = '@AI@'
                                  tooltip = lp_text ).
      CATCH cx_salv_existing INTO rf_root ##NO_HANDLER.
    ENDTRY.
    TRY.
        lp_text = 'Marked for re-import to target environment'(w18).
        lr_tooltips->add_tooltip( type    = cl_salv_tooltip=>c_type_symbol
                                  value   = '@K3@'
                                  tooltip = lp_text ).
      CATCH cx_salv_existing INTO rf_root ##NO_HANDLER.
    ENDTRY.
    TRY.
        lp_text = 'Newer version in target environment!'(w01).
        lr_tooltips->add_tooltip( type    = cl_salv_tooltip=>c_type_symbol
                                  value   = '@F1@'
                                  tooltip = lp_text ).
      CATCH cx_salv_existing INTO rf_root ##NO_HANDLER.
    ENDTRY.
    TRY.
        lp_text = 'Object missing in list and target environment!'(w05).
        lr_tooltips->add_tooltip( type    = cl_salv_tooltip=>c_type_symbol
                                  value   = '@CY@'
                                  tooltip = lp_text ).
      CATCH cx_salv_existing INTO rf_root ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD alv_output.
*   Declaration for Top of List settings
    DATA lr_form_element TYPE REF TO cl_salv_form_element.
    lr_form_element = top_of_page( ).
    rf_table->set_top_of_list( lr_form_element ).
*   Display the ALV output
    rf_table->display( ).
  ENDMETHOD.

  METHOD alv_xls_output.
*   Declaration for Top of List settings
    DATA lr_form_element TYPE REF TO cl_salv_form_element.
    lr_form_element = top_of_page( ).
    rf_table_xls->set_top_of_list( lr_form_element ).
*   Display the ALV output
    rf_table_xls->display( ).
  ENDMETHOD.

  METHOD column_settings.
    TYPES: BEGIN OF ty_field_ran,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE fieldname,
             high   TYPE fieldname,
           END OF ty_field_ran.

    DATA ls_reference        TYPE salv_s_ddic_reference.
    DATA ls_s_column_ref     TYPE salv_s_column_ref.
    DATA lr_column_table     TYPE REF TO cl_salv_column_table.
    DATA ls_colo             TYPE lvc_s_colo.
*   Declaration for Aggregate Function Settings
    DATA lr_aggregations     TYPE REF TO cl_salv_aggregations ##NEEDED.
*   Remove some columns for the XLS output
    DATA lt_range_fieldname  TYPE RANGE OF ty_field_ran.
    DATA ls_fieldname        TYPE ty_field_ran.
*   Hide columns when empty
    DATA lt_range_hide_when_empty TYPE RANGE OF ty_field_ran.
    DATA ls_hide_when_empty  TYPE ty_field_ran.
*   Texts
    DATA lp_short_text       TYPE char10.
    DATA lp_medium_text      TYPE char20.
    DATA lp_long_text        TYPE char40.

    DATA lp_sys_s TYPE REF TO data.
    DATA lp_sys_m TYPE REF TO data.
    DATA lp_sys_l TYPE REF TO data.

    DATA(lp_return) = abap_false.

* Instantiate data references for column headers
    CREATE DATA lp_sys_s TYPE scrtext_s.
    CREATE DATA lp_sys_m TYPE scrtext_m.
    CREATE DATA lp_sys_l TYPE scrtext_l.
    ASSIGN lp_sys_s->* TO FIELD-SYMBOL(<lf_text_s>).      "#EC CI_SUBRC
    ASSIGN lp_sys_m->* TO FIELD-SYMBOL(<lf_text_m>).      "#EC CI_SUBRC
    ASSIGN lp_sys_l->* TO FIELD-SYMBOL(<lf_text_l>).      "#EC CI_SUBRC

*   Build range for all unwanted columns:
    CASE im_table.
      WHEN rf_table_xls.
        ls_fieldname-option = 'EQ'.
        ls_fieldname-sign = 'I'.
        ls_fieldname-low = 'CHECKED'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'OBJECT'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'OBJ_NAME'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'OBJKEY'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'KEYOBJECT'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'KEYOBJNAME'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'TABKEY'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'PGMID'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'DEV'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'QAS'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'PRD'.
        APPEND ls_fieldname TO lt_range_fieldname.
        ls_fieldname-low = 'STATUS_TEXT'.
        APPEND ls_fieldname TO lt_range_fieldname.
      WHEN rf_table.
        ls_fieldname-option = 'EQ'.
        ls_fieldname-sign = 'I'.
        ls_fieldname-low = 'RE_IMPORT'.
        APPEND ls_fieldname TO lt_range_fieldname.
    ENDCASE.
*   Always remove the following colums, regardless of which table is used
    ls_fieldname-option = 'EQ'.
    ls_fieldname-sign = 'I'.
    ls_fieldname-low = 'TRSTATUS'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'TRFUNCTION'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'TROBJ_NAME  '.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'FLAG'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'OBJFUNC'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'CHECKED_BY'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'WARNING_RANK'.
    APPEND ls_fieldname TO lt_range_fieldname.

*   Hide when empty
    ls_hide_when_empty-option = 'EQ'.
    ls_hide_when_empty-sign   = 'I'.
    ls_hide_when_empty-low    = 'OBJKEY'.
    APPEND ls_hide_when_empty TO lt_range_hide_when_empty.
    ls_hide_when_empty-low    = 'KEYOBJECT'.
    APPEND ls_hide_when_empty TO lt_range_hide_when_empty.
    ls_hide_when_empty-low    = 'KEYOBJNAME'.
    APPEND ls_hide_when_empty TO lt_range_hide_when_empty.
    ls_hide_when_empty-low    = 'TABKEY'.
    APPEND ls_hide_when_empty TO lt_range_hide_when_empty.
    ls_hide_when_empty-low    = 'PROJECT'.
    APPEND ls_hide_when_empty TO lt_range_hide_when_empty.
    ls_hide_when_empty-low    = 'PROJECT_DESCR'.
    APPEND ls_hide_when_empty TO lt_range_hide_when_empty.

    LOOP AT im_column_ref INTO ls_s_column_ref.
      TRY.
          lr_column_table ?=
            im_rf_columns_table->get_column( ls_s_column_ref-columnname ).
        CATCH cx_salv_not_found INTO rf_root.
          handle_error( rf_root ).
      ENDTRY.
      IF lr_column_table IS NOT INITIAL.
*       Make Mandt column invisible
        IF lr_column_table->get_ddic_datatype( ) = 'CLNT'.
          lr_column_table->set_technical( if_salv_c_bool_sap=>true ).
        ENDIF.
*       Create Aggregate function total for All Numeric/Currency Fields
        IF lr_column_table->get_ddic_inttype( ) = 'P'
            OR lr_column_table->get_ddic_datatype( ) = 'CURR'.
          IF lr_aggregations IS NOT INITIAL.
            TRY.
                lr_aggregations->add_aggregation(
                                 columnname  = ls_s_column_ref-columnname
                                 aggregation = if_salv_c_aggregation=>total ).
              CATCH cx_salv_data_error INTO rf_root.
                handle_error( rf_root ).
              CATCH cx_salv_not_found INTO rf_root.
                handle_error( rf_root ).
              CATCH cx_salv_existing INTO rf_root.
                handle_error( rf_root ).
            ENDTRY.
          ENDIF.
        ENDIF.
*       Create Check box for fields with domain "XFELD"
        IF lr_column_table->get_ddic_domain( ) = 'XFELD'.
          lr_column_table->set_cell_type( if_salv_c_cell_type=>checkbox ).
        ENDIF.
*       Set color to Date Columns
        IF lr_column_table->get_ddic_datatype( ) = 'DATS'
            OR lr_column_table->get_ddic_datatype( ) = 'TIMS'.
          CLEAR ls_colo.
          ls_colo-col = 2.
          ls_colo-int = 1.
          ls_colo-inv = 1.
          lr_column_table->set_color( ls_colo ).
        ENDIF.
*       Remove columns that are not required
        IF lr_column_table->get_columnname( ) IN lt_range_fieldname.
          lr_column_table->set_technical( if_salv_c_bool_sap=>true ).
        ENDIF.
*       Remove columns that are not required when empty
        IF lr_column_table->get_columnname( ) IN lt_range_hide_when_empty.
          lp_return = is_empty_column( im_column = ls_s_column_ref-columnname
                                       im_table  = main_list ).
          IF lp_return = abap_true.
            lr_column_table->set_technical( if_salv_c_bool_sap=>true ).
          ENDIF.
        ENDIF.
        CASE lr_column_table->get_columnname( ).
          WHEN 'TRKORR'.
*           Add Hotspot & Hyper Link
            lr_column_table->set_cell_type( if_salv_c_cell_type=>hotspot ).
            lr_column_table->set_key( if_salv_c_bool_sap=>true ).
          WHEN 'OBJ_NAME'.
*           Add Hotspot & Hyper Link
            lr_column_table->set_cell_type( if_salv_c_cell_type=>hotspot ).
          WHEN 'CHECKED'.
            IF check_flag = abap_true.
              lp_short_text  = 'Checked'(044).
              lp_long_text   = 'Checked'(044).
              lp_medium_text = 'Checked'(044).
              lr_column_table->set_short_text( lp_short_text ).
              lr_column_table->set_medium_text( lp_medium_text ).
              lr_column_table->set_long_text( lp_long_text ).
              lr_column_table->set_alignment( if_salv_c_alignment=>centered ).
            ELSE.
              lr_column_table->set_technical( ).
            ENDIF.
          WHEN 'INFO'.
            ls_reference-table = 'RSPRINT'.
            ls_reference-field = 'DOKU'.
            lr_column_table->set_ddic_reference( ls_reference ).
            lr_column_table->set_alignment( if_salv_c_alignment=>centered ).
            lr_column_table->set_icon( ).
          WHEN 'CHECKED_BY'.
            IF check_flag = ''.
              lr_column_table->set_technical( ).
            ENDIF.
          WHEN 'RETCODE'.
            lp_short_text  = 'RC'(015).
            lp_medium_text = 'Return Code'(016).
            lp_long_text   = 'Return Code'(016).
            lr_column_table->set_short_text( lp_short_text ).
            lr_column_table->set_medium_text( lp_medium_text ).
            lr_column_table->set_long_text( lp_long_text ).
          WHEN 'STATUS_TEXT'.
            lp_short_text  = 'Descript.'(017).
            lp_medium_text = 'Description'(018).
            lp_long_text   = 'Description'(018).
            lr_column_table->set_short_text( lp_short_text ).
            lr_column_table->set_medium_text( lp_medium_text ).
            lr_column_table->set_long_text( lp_long_text ).
          WHEN 'WARNING_LVL'.
            IF check_flag = abap_true.
              lp_short_text  = 'Warning'(045).
              lp_medium_text = 'Warning'(045).
              lp_long_text   = 'Warning'(045).
              lr_column_table->set_short_text( lp_short_text ).
              lr_column_table->set_medium_text( lp_medium_text ).
              lr_column_table->set_long_text( lp_long_text ).
              lr_column_table->set_icon( ).
            ELSE.
              lr_column_table->set_technical( ).
            ENDIF.
          WHEN 'WARNING_TXT'.
            IF check_flag = abap_true.
              lp_short_text  = 'Warn. text'(046).
              lp_medium_text = 'Warning message'(054).
              lp_long_text   = 'Warning message'(054).
              lr_column_table->set_short_text( lp_short_text ).
              lr_column_table->set_medium_text( lp_medium_text ).
              lr_column_table->set_long_text( lp_long_text ).
            ELSE.
              lr_column_table->set_technical( ).
            ENDIF.
          WHEN 'PROJECT'.
            lp_short_text  = 'Project Nr'(055).
            lp_medium_text = 'Project Number'(056).
            lp_long_text   = 'Project Number'(056).
            lr_column_table->set_short_text( lp_short_text ).
            lr_column_table->set_medium_text( lp_medium_text ).
            lr_column_table->set_long_text( lp_long_text ).
          WHEN 'STATUS'.
            ls_reference-table = 'TRHEADER'.
            ls_reference-field = 'TRSTATUS'.
            lr_column_table->set_ddic_reference( ls_reference ).
            lr_column_table->set_key( ).
          WHEN 'DEV'.
            <lf_text_s> = dev_system.
            <lf_text_m> = dev_system.
            <lf_text_l> = dev_system.
            IF <lf_text_s> IS ASSIGNED.
              lr_column_table->set_short_text( <lf_text_s> ).
            ENDIF.
            IF <lf_text_m> IS ASSIGNED.
              lr_column_table->set_medium_text( <lf_text_m> ).
            ENDIF.
            IF <lf_text_l> IS ASSIGNED.
              lr_column_table->set_long_text( <lf_text_l> ).
            ENDIF.
            lr_column_table->set_icon( ).
          WHEN 'QAS'.
            <lf_text_s> = qas_system.
            <lf_text_m> = qas_system.
            <lf_text_l> = qas_system.
            IF <lf_text_s> IS ASSIGNED.
              lr_column_table->set_short_text( <lf_text_s> ).
            ENDIF.
            IF <lf_text_m> IS ASSIGNED.
              lr_column_table->set_medium_text( <lf_text_m> ).
            ENDIF.
            IF <lf_text_l> IS ASSIGNED.
              lr_column_table->set_long_text( <lf_text_l> ).
            ENDIF.
            lr_column_table->set_icon( ).
          WHEN 'PRD'.
            IF <lf_text_l> IS ASSIGNED.
              <lf_text_s> = prd_system.
              <lf_text_m> = prd_system.
              <lf_text_l> = prd_system.
              IF <lf_text_s> IS ASSIGNED.
                lr_column_table->set_short_text( <lf_text_s> ).
              ENDIF.
              IF <lf_text_m> IS ASSIGNED.
                lr_column_table->set_medium_text( <lf_text_m> ).
              ENDIF.
              IF <lf_text_l> IS ASSIGNED.
                lr_column_table->set_long_text( <lf_text_l> ).
              ENDIF.
              lr_column_table->set_icon( ).
            ENDIF.
          WHEN 'RE_IMPORT'.
            lp_short_text  = 'Import again'(059).
            lp_medium_text = 'Import again'(059).
            lp_long_text   = 'Import again'(059).
            lr_column_table->set_short_text( lp_short_text ).
            lr_column_table->set_medium_text( lp_medium_text ).
            lr_column_table->set_long_text( lp_long_text ).
        ENDCASE.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD is_empty_column.
    DATA ls_line TYPE ty_request_details.
    FIELD-SYMBOLS <lf_column> TYPE any.
    re_is_empty = abap_true.
    LOOP AT im_table INTO ls_line.
      ASSIGN COMPONENT im_column OF STRUCTURE ls_line TO <lf_column>.
      IF sy-subrc = 0 AND <lf_column> IS NOT INITIAL.
        re_is_empty = abap_false.
        EXIT.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD docu_call.

    DATA lv_langu TYPE ddlanguage.

* Get used language for existing documentation
    SELECT SINGLE langu
           FROM   dokil
           INTO   @lv_langu
           WHERE  object = @im_object
           AND    id     = @im_id ##WARN_OK.
    IF sy-subrc <> 0.
      lv_langu = co_langu.
    ENDIF.

* Call the documentation
    CALL FUNCTION 'DOCU_CALL'
      EXPORTING
        displ      = im_display
        displ_mode = im_displ_mode
        id         = im_id
        langu      = lv_langu
        object     = im_object
      EXCEPTIONS
        wrong_name = 1
        OTHERS     = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDMETHOD.

  METHOD determine_col_width.
* This method determines the width of a column in the detailed output
* lists (for conflicts or no-checks overviews). The length of the
* largest value is used as column width. This column width is then used
* in the fielddif table for function "STC1_POPUP_WITH_TABLE_CONTROL".
* This is done to downsize the width of the column as much as possible.
    DATA(lp_value) = 0.
    IF im_field IS NOT INITIAL.
      lp_value = strlen( im_field ).
      IF lp_value > ch_colwidth.
        ch_colwidth = lp_value.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD determine_warning_text.
    CASE im_highest_rank.
      WHEN 0.
*       ICON_LED_GREEN
        CLEAR re_highest_text.
      WHEN 5.
*       ICON_FAILURE
        re_highest_text = lp_alert0_text.
      WHEN 6.
*       ICON_FAILURE
        re_highest_text = lp_alert1_text.
      WHEN 7.
*       ICON_FAILURE
        re_highest_text = lp_alert2_text.
      WHEN 8.
*       ICON_FAILURE
        re_highest_text  = lp_alert3_text.
      WHEN 10.
*       ICON_HINT
        re_highest_text = lp_hint1_text.
      WHEN 12.
*       ICON_HINT
        re_highest_text = lp_hint2_text.
      WHEN 14.
*       ICON_HINT
        re_highest_text = lp_hint3_text.
      WHEN 16.
*       ICON_HINT
        re_highest_text = lp_hint4_text.
      WHEN 20.
*       ICON_INFORMATION
        re_highest_text = lp_info_text.
      WHEN 50.
*       ICON_LED_YELLOW
        re_highest_text = lp_warn_text.
      WHEN 98.
*       ICON_INCOMPLETE
        re_highest_text = lp_ddic_text.
      WHEN 99.
*       ICON_LED_RED
        re_highest_text = lp_error_text.
      WHEN OTHERS.
        CLEAR re_highest_text.
    ENDCASE.
  ENDMETHOD.

  METHOD get_tps_for_same_object.

    DATA lt_aggr_tp_list_of_objects TYPE ty_request_details_tt.
    DATA ls_tp_same_object          TYPE ty_request_details.
    DATA lp_index                   TYPE sytabix.
    DATA lp_return                  TYPE sysubrc.

    FREE ex_newer.
    FREE ex_older.

*   First check if the transports for the object have already been read
*   and stored in the table. If so, then we do not need to retrieve all
*   the transports again (to speed things up a bit).
    SORT aggr_tp_list_of_objects BY object
                                    obj_name
                                    keyobject
                                    keyobjname
                                    tabkey.
    READ TABLE aggr_tp_list_of_objects
               WITH KEY object     = im_line-object
                        obj_name   = im_line-obj_name
                        keyobject  = im_line-keyobject
                        keyobjname = im_line-keyobjname
                        tabkey     = im_line-tabkey
               TRANSPORTING NO FIELDS
               BINARY SEARCH.
    IF sy-subrc <> 0.
*     The transports for this object have not been retrieved yet, so we
*     do that now:
      SELECT a~trkorr, b~object, b~obj_name, b~objfunc,
             a~as4user, a~as4date, a~as4time
             FROM e070 AS a JOIN e071 AS b
                       ON a~trkorr = b~trkorr
             APPENDING CORRESPONDING FIELDS OF TABLE @lt_aggr_tp_list_of_objects
             WHERE a~trkorr NOT IN @project_trkorrs
               AND a~trfunction <> 'T'
               AND b~obj_name   IN @excluded_objects
               AND a~strkorr    = ''
               AND a~trkorr     LIKE @prefix
               AND b~object     = @im_line-object
               AND b~obj_name   = @im_line-obj_name.      "#EC CI_SUBRC

*   Also read from version table, because in some case, the object can
*   be part of a 'bigger' group.
*   Example 1: - a Function Module (FUNC) is transported in one
*                transport, but the entire functiongroup (FUGR) in
*                another (this also transports the FM)
*   Example 2: - A table (TABL) is part of a table definition (TABD), so
*                should also be treated as the same object.
      CLEAR ls_tp_same_object.
      SELECT korrnum AS trkorr,
             objtype AS object,
             objname AS obj_name,
             author  AS as4user
             FROM vrsd
             INNER JOIN e070 ON vrsd~korrnum = e070~trkorr
             APPENDING CORRESPONDING FIELDS OF TABLE @lt_aggr_tp_list_of_objects
             WHERE korrnum NOT IN @project_trkorrs
               AND objname IN @excluded_objects
               AND korrnum <> @im_line-trkorr
               AND korrnum LIKE @prefix
               AND korrnum <> ''
               AND objtype = @im_line-object
               AND objname = @im_line-obj_name          "#EC CI_NOFIELD
               AND e070~trfunction <> 'T'
               ORDER BY korrnum, objtype, objname, author. "#EC CI_SUBRC

*     Remove duplicates:
      SORT lt_aggr_tp_list_of_objects[] BY trkorr object obj_name.
      DELETE ADJACENT DUPLICATES FROM lt_aggr_tp_list_of_objects
                                 COMPARING trkorr object obj_name.

*     If the object is a table, we need to be able to check the keys.
*     Replace the entry with all entries containing the keys.
      IF im_line-objfunc = 'K'.
        add_table_keys_to_list( CHANGING ch_table = lt_aggr_tp_list_of_objects ).
      ENDIF.

*     Now get the last date the object was imported:
      LOOP AT lt_aggr_tp_list_of_objects INTO ls_tp_same_object.
        lp_index = sy-tabix.
*       Remove all transports from a source system not known (usually an
*       SAP system, not one of our systems).
        IF ls_tp_same_object-trkorr(3) NOT IN systems_range.
          DELETE lt_aggr_tp_list_of_objects INDEX sy-tabix.
          CONTINUE.
        ENDIF.
*       Now get the global information on the transport:
*       Get the last date the object was imported
        get_import_datetime_qas( EXPORTING im_trkorr  = ls_tp_same_object-trkorr
                                 IMPORTING ex_as4time = ls_tp_same_object-as4time
                                           ex_as4date = ls_tp_same_object-as4date
                                           ex_return  = lp_return ).
        IF lp_return = 0.
          MODIFY lt_aggr_tp_list_of_objects FROM ls_tp_same_object
                                            INDEX lp_index
                                            TRANSPORTING as4time as4date. "#EC CI_SUBRC
        ELSE.
          DELETE lt_aggr_tp_list_of_objects INDEX lp_index.
        ENDIF.
      ENDLOOP.
*     Add the newly retrieved lines to the internal table:
      APPEND LINES OF lt_aggr_tp_list_of_objects TO aggr_tp_list_of_objects.
    ENDIF.

*   Move newer transports for this object to the relevant internal table:
    LOOP AT aggr_tp_list_of_objects INTO ls_tp_same_object
                                    WHERE object     = im_line-object
                                      AND obj_name   = im_line-obj_name
                                      AND keyobject  = im_line-keyobject
                                      AND keyobjname = im_line-keyobjname
                                      AND tabkey     = im_line-tabkey
                                      AND trkorr     <> im_line-trkorr.
*     If on the same date, check if the time is later
      IF ls_tp_same_object-as4date = im_line-as4date.
        IF ls_tp_same_object-as4time >= im_line-as4time.
          APPEND ls_tp_same_object TO ex_newer.
        ELSE.
          APPEND ls_tp_same_object TO ex_older.
        ENDIF.
      ELSEIF ls_tp_same_object-as4date  > im_line-as4date.
        APPEND ls_tp_same_object TO ex_newer.
      ELSE.
        APPEND ls_tp_same_object TO ex_older.
      ENDIF.
    ENDLOOP.

    SORT ex_newer BY as4date DESCENDING as4time DESCENDING.
    SORT ex_older BY as4date DESCENDING as4time DESCENDING.

  ENDMETHOD.

  METHOD handle_error.
    DATA(lp_msg) = im_oref->get_text( ).
    CONCATENATE 'ERROR:'(038) lp_msg INTO lp_msg SEPARATED BY space.
    MESSAGE lp_msg TYPE 'E'.
  ENDMETHOD.

  METHOD check_colwidth.
    DATA lp_as4text   TYPE as4text.
    SELECT SINGLE scrtext_s
             FROM dd04t INTO @lp_as4text
            WHERE rollname   = @im_name
              AND ddlanguage = @co_langu.                 "#EC CI_SUBRC
    IF lp_as4text IS INITIAL.
      SELECT SINGLE scrtext_m
                    FROM dd04t INTO @lp_as4text
                   WHERE rollname   = @im_name
                     AND ddlanguage = @co_langu.          "#EC CI_SUBRC
      IF lp_as4text IS INITIAL.
        SELECT SINGLE scrtext_l
                 FROM dd04t INTO @lp_as4text
                WHERE rollname   = @im_name
                  AND ddlanguage = @co_langu.             "#EC CI_SUBRC
      ENDIF.
    ENDIF.
    DATA(lp_len) = strlen( lp_as4text ).
    IF lp_len > im_colwidth.
      re_colwidth = lp_len.
    ELSE.
      re_colwidth = im_colwidth.
    ENDIF.
  ENDMETHOD.

  METHOD remove_tp_in_prd.
    LOOP AT main_list TRANSPORTING NO FIELDS WHERE prd = co_okay.
      DELETE main_list INDEX sy-tabix.
    ENDLOOP.
  ENDMETHOD.

  METHOD sort_list.
    SORT ch_list BY as4date   ASCENDING
                      as4time    ASCENDING
                      trkorr     ASCENDING
                      object     ASCENDING
                      obj_name   ASCENDING
                      objkey     ASCENDING
                      keyobject  ASCENDING
                      keyobjname ASCENDING
                      tabkey     ASCENDING.
    DELETE ADJACENT DUPLICATES FROM ch_list COMPARING ALL FIELDS.
  ENDMETHOD.

  METHOD top_of_page.
    DATA lr_logo             TYPE REF TO cl_salv_form_layout_logo.
    DATA lp_head             TYPE char50.
    DATA lp_file_in          TYPE localfile.                "#EC NEEDED
    DATA lp_file_out         TYPE localfile.
    DATA lp_picture          TYPE bds_typeid VALUE 'LOGO_MEDIQ_ALV_129X45'.
    DATA lr_rows             TYPE REF TO cl_salv_form_layout_grid.
    DATA lr_rows_flow        TYPE REF TO cl_salv_form_layout_flow.
    DATA lr_row              TYPE REF TO cl_salv_form_layout_flow.

    DATA(lp_records_found) = VALUE numc5( ).

    lr_rows_flow = NEW #( ).
    lr_rows = lr_rows_flow->create_grid( ).
    lr_rows->create_grid( row     = 4
                          column  = 0
                          rowspan = 0
                          colspan = 0 ).
*   Header of Top of Page
    lp_head = 'Information'(t05) ##TEXT_DUP.
    lr_row = lr_rows->add_row( ).
    lr_row->create_header_information( text = lp_head ).
*   Split filename from path
    IF filename IS NOT INITIAL.
      lp_file_out = filename.
      DO.
        IF lp_file_out CS '\'.
          SPLIT lp_file_out AT '\' INTO lp_file_in lp_file_out.
        ELSE.
          EXIT.
        ENDIF.
      ENDDO.
      lr_row = lr_rows->add_row( ).
      lr_row = lr_rows->add_row( ).
      lr_row->create_label( text = 'File uploaded:'(049) ).
      lr_row->create_text( text = ' ' ).
      lr_row->create_text( text = lp_file_out(50) ).
    ENDIF.
    lr_row = lr_rows->add_row( ).
    CONCATENATE 'If there is a warning icon in column ''Warning'', double-clicking on the'(h01)
                'icon will display a list of objects that should be checked.'(h02)
                 INTO DATA(lp_string) SEPARATED BY space.
    lr_row->create_text( text = lp_string ).
    lr_row = lr_rows->add_row( ).
    CONCATENATE 'You can add these conflicts by means of the button ''Add Conflicts'' in'(h03)
                'the application toolbar or doubleclicking the warning.'(h04)
                 INTO lp_string SEPARATED BY space.
    lr_row->create_text( text = lp_string ).
    lr_row = lr_rows->add_row( ).
    lr_row = lr_rows->add_row( ).
    lr_row->create_label( text = 'No of Records found:'(t04) ).
    CASE sy-ucomm.
      WHEN '&PREP_XLS'.
        lp_records_found = lines( main_list_xls ).
      WHEN OTHERS.
        lp_records_found = lines( main_list ).
    ENDCASE.
    lr_row->create_text( text = ' ' ).
    lr_row->create_text(
            text    = lp_records_found
            tooltip = lp_records_found ).
*   Create logo layout, set grid content on left and logo image on right
    lr_logo = NEW #( ).
    lr_logo->set_left_content( lr_rows_flow ).
    lr_logo->set_right_logo( lp_picture ).
    re_form_element = lr_logo.
  ENDMETHOD.

  METHOD display_excel.
    DATA lp_return        TYPE c.
    DATA lp_highest_lvl   TYPE icon_d.
    DATA lp_highest_rank  TYPE numc4.
    DATA lp_highest_text  TYPE text74.
    DATA lp_highest_col   TYPE lvc_t_scol.

*   Only when called from the Main Screen (Object Level). Do not build again
*   when the XLS list has been build already.
    IF main_list_xls IS NOT INITIAL.
      RETURN.
    ENDIF.
*   Remove duplicate transport numbers (only need single lines):
    main_list_xls[] = im_table[].
    SORT main_list_xls BY trkorr ASCENDING.
    DELETE ADJACENT DUPLICATES FROM main_list_xls COMPARING trkorr.
*   Extra actions:
*   - Make sure to keep the highest warning level
*   - rename Icons to text
*   - remove transports not in QAS
    CLEAR lp_return.
    LOOP AT main_list_xls INTO main_list_line_xls.
      CLEAR: lp_highest_lvl,
             lp_highest_rank,
             lp_highest_text,
             lp_highest_col.
*     Remove transports not in QAS and transports in prd that do not
*     need to be re-transported:
      IF main_list_line_xls-qas <> co_okay
          OR main_list_line_xls-prd = co_okay.
        lp_return = abap_true.
        LOOP AT main_list ASSIGNING FIELD-SYMBOL(<lf_main_list>)
                          WHERE trkorr = main_list_line_xls-trkorr.
          <lf_main_list>-warning_lvl  = co_tp_fail.
          <lf_main_list>-warning_rank = co_tp_fail_rank.
          <lf_main_list>-warning_txt  = lp_fail_text.
        ENDLOOP.
      ENDIF.
*     Rename Documentation Icon to text
      IF main_list_line_xls-info = co_docu.
        main_list_line_xls-info = 'Yes'(037).
      ENDIF.
*     Make sure to find and keep the highest warning level for the
*     transport
      LOOP AT main_list INTO main_list_line
                        WHERE trkorr = main_list_line_xls-trkorr.
        IF main_list_line-warning_rank > lp_highest_rank.
          lp_highest_rank = main_list_line-warning_rank.
          lp_highest_lvl  = main_list_line-warning_lvl.
          lp_highest_text = main_list_line-warning_txt.
          lp_highest_col  = main_list_line-t_color.
        ENDIF.
      ENDLOOP.
      refresh_alv( ).
*     Add correct warning and change Warning Lvl Icon to text:
      IF sy-subrc = 0.
        main_list_line_xls-warning_lvl  = lp_highest_lvl.
        main_list_line_xls-warning_rank = lp_highest_rank.
        main_list_line_xls-warning_txt  = lp_highest_text.
        main_list_line_xls-t_color      = lp_highest_col.
        CASE lp_highest_lvl.
          WHEN co_info OR co_hint.
            main_list_line_xls-warning_lvl = 'Info'(024).
          WHEN co_error.
            main_list_line_xls-warning_lvl = 'ERR.'(033).
          WHEN co_ddic.
            main_list_line_xls-warning_lvl = 'ERR.'(033).
          WHEN co_warn.
            main_list_line_xls-warning_lvl = 'Warn'(034).
          WHEN OTHERS.
            CLEAR main_list_line_xls-warning_lvl.
        ENDCASE.
        IF main_list_line-prd = co_scrap.
          main_list_line_xls-re_import = 'Import again'(059).
        ENDIF.
      ENDIF.
*     Apply the changes
      TRY.
          MODIFY main_list_xls FROM main_list_line_xls.
        CATCH cx_root INTO rf_root ##CATCH_ALL.
          handle_error( rf_root ).
      ENDTRY.
    ENDLOOP.
*   Message if entries were deleted because they were not in QAS:
    IF lp_return = abap_true.
      MESSAGE i000(db)
         WITH 'Some transports will be deleted from the list'(m02)
              'because they are missing in Acceptance or are'(m03)
              'already in Production but not marked for'(m04)
              're-import. Please check the main list.'(m05).
      FREE rf_table_xls.
      FREE main_list_xls.
      RETURN.
    ENDIF.
*   Display short list for copy to Excel transport list:
    alv_xls_init( IMPORTING ex_rf_table = rf_table_xls
                  CHANGING  ch_table    = main_list_xls ).
    alv_set_properties( rf_table_xls ).
    alv_xls_output( ).
    FREE rf_table_xls.
    FREE main_list_xls.
  ENDMETHOD.

  METHOD set_properties_conflicts.
    TYPES: BEGIN OF ty_field_ran,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE fieldname,
             high   TYPE fieldname,
           END OF ty_field_ran.
    DATA ls_s_column_ref        TYPE salv_s_column_ref.
    DATA lr_column_table        TYPE REF TO cl_salv_column_table.
*   Declaration for Aggregate Function Settings
    DATA lr_aggregations        TYPE REF TO cl_salv_aggregations.
    DATA ls_table               TYPE ty_request_details.
    DATA lp_cw_columns          TYPE lvc_outlen.
    DATA lp_cw_korrnum          TYPE lvc_outlen.
    DATA lp_cw_tr_descr         TYPE lvc_outlen.
    DATA lp_cw_object           TYPE lvc_outlen.
    DATA lp_cw_obj_name         TYPE lvc_outlen.
    DATA lp_cw_tabkey           TYPE lvc_outlen.
    DATA lp_cw_author           TYPE lvc_outlen.
    DATA lp_cw_reimport         TYPE lvc_outlen.
    DATA lp_cw_warning_lvl      TYPE lvc_outlen.
    DATA lp_cw_date             TYPE lvc_outlen.
    DATA lp_cw_time             TYPE lvc_outlen.
    DATA lp_cw_keyobject        TYPE lvc_outlen.
    DATA lp_cw_keyobjname       TYPE lvc_outlen.
    DATA lr_table_des           TYPE REF TO cl_abap_structdescr.
    DATA lt_details             TYPE abap_compdescr_tab.
    DATA ls_details             TYPE abap_compdescr.
    DATA lp_field               TYPE string.
*   Declaration for ALV Columns
    DATA lr_columns_table       TYPE REF TO cl_salv_columns_table.
    DATA lt_t_column_ref        TYPE salv_t_column_ref.
*   Declaration for Sort Function Settings
    DATA lr_sorts               TYPE REF TO cl_salv_sorts.
*   Declaration for Table Selection settings
    DATA lr_selections          TYPE REF TO cl_salv_selections.
*   Declaration for Global Display Settings
    DATA lr_display_settings    TYPE REF TO cl_salv_display_settings.
*   Texts
    DATA lp_short_text          TYPE char10.
    DATA lp_medium_text         TYPE char20.
    DATA lp_long_text           TYPE char40.

    DATA(lp_bool) = abap_false.

    FIELD-SYMBOLS <lf_type>    TYPE any.
*   To remove some columns from the output
    DATA lt_range_fieldname     TYPE RANGE OF ty_field_ran.
    DATA ls_fieldname           TYPE ty_field_ran.
*   Individual Column Properties.
*   Build range for all columns to be removed
    ls_fieldname-option = 'EQ'.
    ls_fieldname-sign = 'I'.
    ls_fieldname-low = 'INFO'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'RETCODE'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'TRSTATUS'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'STATUS_TEXT'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'TRFUNCTION'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'TRFUNCTION_TXT'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'OBJKEY'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'OBJFUNC'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'CHECKED_BY'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'PROJECT'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'PROJECT_DESCR'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'WARNING_TXT'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'WARNING_RANK'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'SYSTEMID'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'STEPID'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'DEV'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'QAS'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'PRD'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'FLAG'.
    APPEND ls_fieldname TO lt_range_fieldname.
    ls_fieldname-low = 'CHECKED'.
    APPEND ls_fieldname TO lt_range_fieldname.
*   Create the standard output fields.
*   Get the structure of the table.
    lr_table_des ?=
      cl_abap_typedescr=>describe_by_data( main_list_line ).
    lt_details[] = lr_table_des->components[].
    LOOP AT lt_details INTO ls_details.
      CONCATENATE '>MAIN_LIST_LINE' '-'
                  ls_details-name INTO lp_field.
      ASSIGN (lp_field) TO <lf_type>.
      CHECK <lf_type> IS ASSIGNED.
    ENDLOOP.

*   Determine total width
    LOOP AT im_table INTO ls_table.
      determine_col_width( EXPORTING im_field    = ls_table-trkorr
                           CHANGING  ch_colwidth = lp_cw_korrnum ).
      determine_col_width( EXPORTING im_field    = ls_table-tr_descr
                           CHANGING  ch_colwidth = lp_cw_tr_descr ).
      determine_col_width( EXPORTING im_field    = ls_table-warning_lvl
                           CHANGING  ch_colwidth = lp_cw_warning_lvl ).
      determine_col_width( EXPORTING im_field    = ls_table-object
                           CHANGING  ch_colwidth = lp_cw_object ).
      determine_col_width( EXPORTING im_field    = ls_table-obj_name
                           CHANGING  ch_colwidth = lp_cw_obj_name ).
      determine_col_width( EXPORTING im_field    = ls_table-tabkey
                           CHANGING  ch_colwidth = lp_cw_tabkey ).
      determine_col_width( EXPORTING im_field    = ls_table-keyobject
                           CHANGING  ch_colwidth = lp_cw_keyobject ).
      determine_col_width( EXPORTING im_field    = ls_table-keyobjname
                           CHANGING  ch_colwidth = lp_cw_keyobjname ).
      determine_col_width( EXPORTING im_field    = ls_table-as4date
                           CHANGING  ch_colwidth = lp_cw_date ).
      determine_col_width( EXPORTING im_field    = ls_table-as4time
                           CHANGING  ch_colwidth = lp_cw_time ).
      determine_col_width( EXPORTING im_field    = ls_table-as4user
                           CHANGING  ch_colwidth = lp_cw_author ).
      determine_col_width( EXPORTING im_field    = ls_table-re_import
                           CHANGING  ch_colwidth = lp_cw_reimport ).
    ENDLOOP.
*   Global Display Settings
    CLEAR: lr_display_settings.
*   Global display settings
    lr_display_settings = rf_conflicts->get_display_settings( ).
*   Activate Striped Pattern
    lr_display_settings->set_striped_pattern( if_salv_c_bool_sap=>true ).
*   Report header
    lr_display_settings->set_list_header( sy-title ).
*   Aggregate Function Settings
    lr_aggregations = rf_conflicts->get_aggregations( ).
*   Sort Functions
    lr_sorts = rf_conflicts->get_sorts( ).
    IF lr_sorts IS NOT INITIAL.
      TRY.
          lr_sorts->add_sort( columnname = 'AS4DATE'
                              position   = 1
                              sequence   = if_salv_c_sort=>sort_up
                              subtotal   = if_salv_c_bool_sap=>false
                              obligatory = if_salv_c_bool_sap=>false ).
        CATCH cx_salv_not_found INTO rf_root.
          handle_error( rf_root ).
        CATCH cx_salv_existing INTO rf_root ##NO_HANDLER.
        CATCH cx_salv_data_error INTO rf_root.
          handle_error( rf_root ).
      ENDTRY.
      TRY.
          lr_sorts->add_sort( columnname  = 'AS4TIME'
                               position   = 2
                               sequence   = if_salv_c_sort=>sort_up
                               subtotal   = if_salv_c_bool_sap=>false
                               group      = if_salv_c_sort=>group_none
                               obligatory = if_salv_c_bool_sap=>false ).
        CATCH cx_salv_not_found INTO rf_root.
          handle_error( rf_root ).
        CATCH cx_salv_existing INTO rf_root ##NO_HANDLER.
        CATCH cx_salv_data_error INTO rf_root.
          handle_error( rf_root ).
      ENDTRY.
    ENDIF.
*   Table Selection Settings
    lr_selections = rf_conflicts->get_selections( ).
    IF lr_selections IS NOT INITIAL.
*     Allow row Selection
      lr_selections->set_selection_mode( if_salv_c_selection_mode=>row_column ).
    ENDIF.
*   Event Register settings
    rf_events_table = rf_conflicts->get_event( ).
    rf_handle_events = NEW #( ).
    SET HANDLER lcl_eventhandler_ztct=>on_function_click     FOR rf_events_table.
    SET HANDLER lcl_eventhandler_ztct=>on_double_click_popup FOR rf_events_table.
    SET HANDLER lcl_eventhandler_ztct=>on_link_click_popup   FOR rf_events_table.
*   Get the columns from ALV Table
    lr_columns_table = rf_conflicts->get_columns( ).
    IF lr_columns_table IS NOT INITIAL.
      FREE lt_t_column_ref.
      lt_t_column_ref = lr_columns_table->get( ).
*     Get columns properties
      lr_columns_table->set_optimize( if_salv_c_bool_sap=>true ).
      lr_columns_table->set_key_fixation( if_salv_c_bool_sap=>true ).
      TRY.
          lr_columns_table->set_color_column( 'T_COLOR' ).
        CATCH cx_salv_data_error INTO rf_root.
          handle_error( rf_root ).
      ENDTRY.

      LOOP AT lt_t_column_ref INTO ls_s_column_ref.
        TRY.
            lr_column_table ?=
              lr_columns_table->get_column( ls_s_column_ref-columnname ).
          CATCH cx_salv_not_found INTO rf_root.
            handle_error( rf_root ).
        ENDTRY.
        IF lr_column_table IS NOT INITIAL.
*         Make Mandt column invisible
          IF lr_column_table->get_ddic_datatype( ) = 'CLNT'.
            lr_column_table->set_technical( if_salv_c_bool_sap=>true ).
          ENDIF.
*         Create Aggregate function total for All Numeric/Currency Fields
          IF lr_column_table->get_ddic_inttype( ) = 'P'
              OR lr_column_table->get_ddic_datatype( ) = 'CURR'.
            IF lr_aggregations IS NOT INITIAL.
              TRY.
                  lr_aggregations->add_aggregation(
                                    columnname  = ls_s_column_ref-columnname
                                    aggregation = if_salv_c_aggregation=>total ).
                CATCH cx_salv_data_error INTO rf_root.
                  handle_error( rf_root ).
                CATCH cx_salv_not_found INTO rf_root.
                  handle_error( rf_root ).
                CATCH cx_salv_existing INTO rf_root.
                  handle_error( rf_root ).
              ENDTRY.
            ENDIF.
          ENDIF.
*         Create Check box for fields with domain "XFELD"
          IF lr_column_table->get_ddic_domain( ) = 'XFELD'.
            lr_column_table->set_cell_type( if_salv_c_cell_type=>checkbox ).
          ENDIF.
*         Add Hotspot&Hyper Link to the column vbeln
          IF ls_s_column_ref-columnname = 'TRKORR'.
            lr_column_table->set_cell_type( if_salv_c_cell_type=>hotspot ).
            lr_column_table->set_key( if_salv_c_bool_sap=>true ).
          ENDIF.
*         Remove columns that are not required
          IF lr_column_table->get_columnname( ) IN lt_range_fieldname.
            lr_column_table->set_technical( if_salv_c_bool_sap=>true ).
            CONTINUE.
          ENDIF.
          CASE lr_column_table->get_columnname( ).
            WHEN 'TRKORR'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              lp_cw_korrnum = check_colwidth( im_name     = 'TRKORR'
                                              im_colwidth = lp_cw_korrnum ).
              lr_column_table->set_output_length( lp_cw_korrnum ).
            WHEN 'TR_DESCR'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              lp_cw_tr_descr = check_colwidth( im_name     = 'TR_DESCR'
                                               im_colwidth = lp_cw_tr_descr ).
              lr_column_table->set_output_length( lp_cw_tr_descr ).
            WHEN 'WARNING_LVL'.
              IF check_flag = abap_true.
                lp_short_text  = 'Warning'(045).
                lp_medium_text = 'Warning'(045).
                lp_long_text   = 'Warning'(045).
                lr_column_table->set_short_text( lp_short_text ).
                lr_column_table->set_medium_text( lp_medium_text ).
                lr_column_table->set_long_text( lp_long_text ).
                lr_column_table->set_icon( ).
                lr_column_table->set_output_length( lp_cw_warning_lvl ).
              ELSE.
                lr_column_table->set_technical( ).
              ENDIF.
            WHEN 'OBJECT'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              lp_cw_object = check_colwidth( im_name     = 'OBJECT'
                                             im_colwidth = lp_cw_object ).
              lr_column_table->set_output_length( lp_cw_object ).
            WHEN 'OBJ_NAME'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              lp_cw_obj_name = check_colwidth( im_name     = 'OBJ_NAME'
                                               im_colwidth = lp_cw_obj_name ).
              lr_column_table->set_output_length( lp_cw_obj_name ).
            WHEN 'TABKEY'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              IF lp_cw_tabkey IS INITIAL.
                lr_column_table->set_technical( ).
              ELSE.
                lp_cw_tabkey = check_colwidth( im_name     = 'TABKEY'
                                               im_colwidth = lp_cw_tabkey ).
                lr_column_table->set_output_length( lp_cw_tabkey ).
              ENDIF.
            WHEN 'KEYOBJECT'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              IF lp_cw_keyobject IS INITIAL.
                lr_column_table->set_technical( ).
              ELSE.
                lp_cw_keyobject = check_colwidth( im_name     = 'KEYOBJECT'
                                                  im_colwidth = lp_cw_keyobject ).
                lr_column_table->set_output_length( lp_cw_keyobject ).
              ENDIF.
            WHEN 'KEYOBJNAME'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              IF lp_cw_keyobjname IS INITIAL.
                lr_column_table->set_technical( ).
              ELSE.
                lp_cw_keyobjname = check_colwidth( im_name     = 'KEYOBJNAME'
                                                   im_colwidth = lp_cw_keyobjname ).
                lr_column_table->set_output_length( lp_cw_keyobjname ).
              ENDIF.
            WHEN 'AS4DATE'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              lp_cw_date = check_colwidth( im_name     = 'AS4DATE'
                                           im_colwidth = lp_cw_date ).
              lr_column_table->set_output_length( lp_cw_date ).
            WHEN 'AS4TIME'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              lp_cw_time = check_colwidth( im_name     = 'AS4TIME'
                                           im_colwidth = lp_cw_time ).
              lr_column_table->set_output_length( lp_cw_time ).
            WHEN 'AS4USER'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              lp_cw_author = check_colwidth( im_name     = 'AS4USER'
                                             im_colwidth = lp_cw_author ).
              lr_column_table->set_output_length( lp_cw_author ).
            WHEN 'RE_IMPORT'.
              lr_column_table->set_key( if_salv_c_bool_sap=>false ).
              lp_cw_reimport = check_colwidth( im_name     = 'RE_IMPORT'
                                               im_colwidth = lp_cw_reimport ).
              lr_column_table->set_output_length( lp_cw_reimport ).

          ENDCASE.
*         Count the number of columns that are visible
          lp_bool = lr_column_table->is_technical( ).
          IF lp_bool = abap_false.
            lp_cw_columns = lp_cw_columns + 1.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.

    re_xend = lp_cw_korrnum     + lp_cw_tr_descr   +
              lp_cw_warning_lvl + lp_cw_object     +
              lp_cw_obj_name    + lp_cw_tabkey     +
              lp_cw_keyobject   + lp_cw_keyobjname +
              lp_cw_date        + lp_cw_time       +
              lp_cw_author      + lp_cw_reimport   +
              lp_cw_columns.
  ENDMETHOD.

  METHOD prepare_ddic_check.
    set_ddic_objects( ).
    set_where_used( ).
  ENDMETHOD.

  METHOD set_ddic_objects.
    TYPES: BEGIN OF ty_tadir,
             devclass TYPE devclass,
             obj_name TYPE sobj_name,
           END OF ty_tadir.
    TYPES ty_tadir_tt TYPE STANDARD TABLE OF ty_tadir.
    DATA lt_tadir TYPE ty_tadir_tt.

    FREE ddic_objects.
*   Get all objects in Z-devclasses
    SELECT devclass, obj_name FROM tadir INTO TABLE @lt_tadir
                             WHERE devclass LIKE 'Z%'
                                   ORDER BY PRIMARY KEY.
    IF sy-subrc = 0 AND lt_tadir IS NOT INITIAL.
*     DD01L (Domains)
      IF lt_tadir[] IS NOT INITIAL.
        SELECT domname
               APPENDING TABLE @ddic_objects
               FROM dd01l FOR ALL ENTRIES IN @lt_tadir
              WHERE domname = @lt_tadir-obj_name(30).     "#EC CI_SUBRC
      ENDIF.
*     DD02L (SAP-tables)
      IF lt_tadir[] IS NOT INITIAL.
        SELECT tabname
               APPENDING TABLE @ddic_objects
               FROM dd02l FOR ALL ENTRIES IN @lt_tadir
              WHERE tabname = @lt_tadir-obj_name(30).     "#EC CI_SUBRC
      ENDIF.
*     DD04L (Data elements)
      IF lt_tadir[] IS NOT INITIAL.
        SELECT rollname
               APPENDING TABLE @ddic_objects
               FROM dd04l FOR ALL ENTRIES IN @lt_tadir
              WHERE rollname = @lt_tadir-obj_name(30).    "#EC CI_SUBRC
      ENDIF.
      SORT ddic_objects.
      DELETE ADJACENT DUPLICATES FROM ddic_objects.
    ENDIF.
  ENDMETHOD.

  METHOD do_ddic_check.
    DATA ls_ddic_conflict_info TYPE ty_request_details.
    DATA ls_main              TYPE ty_request_details.
    DATA lp_obj_name          TYPE trobj_name.
*  Check if the object exists in the where_used list for data
*  dictionary elements that do not yet exist in production.
*  If it is found in the where_used list, then the object MUST
*  also be in the main transport list. If it is not, it is an ERROR,
*  because transporting to production will cause DUMPS.
*  Check is independent of Flags. (Re)Check all objects in the list!
*  Message: "Contains an object that does not exist in prod. and
*            is not in the list"
    LOOP AT ch_main_list INTO ls_main.
      LOOP AT where_used INTO where_used_line
                         WHERE object = ls_main-obj_name.
*       If the used object (i.e. element, domain etc) is in the DDIC_E071 list,
*       it means that the used object is NOT in production yet. Transporting
*       the object that uses this used object will cause dumps in production.
        READ TABLE ddic_e071 INTO ddic_e071_line
                             WITH KEY obj_name = where_used_line-used_obj.
*       The object in this transport contains a DDIC object that is not yet in
*       Production. This will cause dumps, unless the DDIC object can be found
*       as an object in the transport list!
        IF sy-subrc = 0.
*         Check if the used object can be found in the main list
          IF NOT line_exists( ch_main_list[ obj_name = where_used_line-used_obj ] ).
            IF ls_main-flag = abap_true.
              lp_obj_name = where_used_line-used_obj.
              ls_ddic_conflict_info = get_tp_info( im_trkorr   = ddic_e071_line-trkorr
                                                   im_obj_name = lp_obj_name ).
              conflict_line = CORRESPONDING #( ls_ddic_conflict_info ).
              conflict_line-warning_lvl  = co_ddic.
              conflict_line-warning_rank = co_ddic_rank.
              conflict_line-warning_txt  = lp_ddic_text.
              APPEND conflict_line TO conflicts.
              CLEAR conflict_line.
            ENDIF.
            ls_main-warning_lvl  = co_ddic.
            ls_main-warning_rank = co_ddic_rank.
            ls_main-warning_txt  = lp_ddic_text.
            MODIFY ch_main_list FROM ls_main TRANSPORTING warning_lvl
                                                          warning_rank
                                                          warning_txt
                                                          t_color.
            total = total + 1.
          ELSEIF ls_main-warning_rank = co_ddic_rank.
            ls_main-flag         = abap_true.
            MODIFY ch_main_list FROM ls_main TRANSPORTING flag.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD set_where_used.
    DATA lt_stms_wbo_requests TYPE TABLE OF stms_wbo_request.
    DATA ls_stms_wbo_requests TYPE stms_wbo_request.
    DATA ls_systems           TYPE ctslg_system.
    DATA lp_scope             TYPE seu_obj ##NEEDED.
    DATA lp_answer            TYPE char1 ##NEEDED.
    DATA lp_index             TYPE syindex.
    DATA lp_counter           TYPE i.
    DATA lp_total             TYPE sytabix.
    DATA lp_obj_name          TYPE trobj_name.
    DATA lt_objrangtab        TYPE objrangtab.
    DATA ls_objtyprang        TYPE objtyprang.
    DATA lt_objtype           TYPE TABLE OF versobjtyp.
    DATA lp_chars             TYPE string VALUE '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    DATA lt_where_used_sub    TYPE sci_findlst.
    DATA lp_string            TYPE string.

    DATA(ls_ddic_object) = VALUE string( ).
    DATA(ls_objects)     = VALUE string( ).
    DATA(lp_deleted)     = VALUE abap_bool( ).

    FREE ddic_e071.
* Get all object types
* Select values for pgmid/object/text from database--------------------
* Get all object types that have been transported before
    SELECT DISTINCT object FROM e071 INTO TABLE @lt_objtype.
    IF sy-subrc = 0.
      ls_objtyprang-sign   = 'I'.
      ls_objtyprang-option = 'EQ'.
      LOOP AT lt_objtype INTO ls_objtyprang-low.
        IF ls_objtyprang-low CN lp_chars.
          CONTINUE.
        ENDIF.
        APPEND ls_objtyprang TO lt_objrangtab.
      ENDLOOP.
    ENDIF.
* Now find ALL transports for the DDIC objects with Program ID R3TR,
* for the object types found
    CLEAR lp_counter.
    lp_total = lines( ddic_objects ).
    LOOP AT ddic_objects INTO ls_ddic_object.
      lp_counter = lp_counter + 1.
      lp_obj_name = ls_ddic_object.
      progress_indicator( im_counter = lp_counter
                          im_object  = lp_obj_name
                          im_total   = lp_total
                          im_text    = 'Collecting DDIC transports'(053)
                          im_flag    = ' ' ).
      SELECT trkorr, pgmid, object, obj_name
             FROM e071 APPENDING CORRESPONDING FIELDS OF TABLE @ddic_e071
            WHERE pgmid    = 'R3TR'
              AND object   IN @lt_objrangtab
              AND obj_name = @ls_ddic_object. "#EC CI_SEL_NESTED #EC CI_SUBRC
    ENDLOOP.

*   Check if the transport is in production, if it is, then the
*   DDIC object is existing and 'should' not cause problems.
    CLEAR lp_counter.
    LOOP AT ddic_e071 INTO ddic_e071_line.
      lp_index = sy-tabix.
      lp_deleted = abap_false.
      IF ddic_e071_line-trkorr(3) NS dev_system.
*       Not a Development transport, check not required
        DELETE ddic_e071 INDEX lp_index.
        CONTINUE.
      ENDIF.
      FREE lt_stms_wbo_requests.
      CLEAR lt_stms_wbo_requests.
      READ TABLE tms_mgr_buffer INTO tms_mgr_buffer_line
                      WITH TABLE KEY request       = ddic_e071_line-trkorr
                                     target_system = dev_system.
      IF sy-subrc = 0.
        lt_stms_wbo_requests = tms_mgr_buffer_line-request_infos.
      ELSE.
        CALL FUNCTION 'TMS_MGR_READ_TRANSPORT_REQUEST'
          EXPORTING
            iv_request                 = ddic_e071_line-trkorr
            iv_target_system           = dev_system
            iv_header_only             = 'X'
            iv_monitor                 = ' '
          IMPORTING
            et_request_infos           = lt_stms_wbo_requests
          EXCEPTIONS
            read_config_failed         = 1
            table_of_requests_is_empty = 2
            system_not_available       = 3
            OTHERS                     = 4.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                  WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ELSE.
          tms_mgr_buffer_line-request       = ddic_e071_line-trkorr.
          tms_mgr_buffer_line-target_system = dev_system.
          tms_mgr_buffer_line-request_infos = lt_stms_wbo_requests.
          INSERT tms_mgr_buffer_line INTO TABLE tms_mgr_buffer.
        ENDIF.
      ENDIF.
      READ TABLE lt_stms_wbo_requests INDEX 1
                                      INTO ls_stms_wbo_requests.
      IF sy-subrc = 0.
        IF ls_stms_wbo_requests-e070-trstatus NA 'NR'.
*       Transport not released, check not required
          DELETE ddic_e071 INDEX lp_index.
          lp_deleted = abap_true.
        ELSEIF ls_stms_wbo_requests-e070-trstatus = 'O'.
          MESSAGE e000(db) DISPLAY LIKE 'E'
                           WITH 'Transport being released. Recheck needed!'(060).
        ELSE.
*       Retrieve the environments where the transport can be found.
*       Read the info of the request (transport log) to determine the
*       highest environment the transport has been moved to.
          CALL FUNCTION 'TR_READ_GLOBAL_INFO_OF_REQUEST'
            EXPORTING
              iv_trkorr = ddic_e071_line-trkorr
            IMPORTING
              es_cofile = st_request-cofile.
          IF st_request-cofile-systems IS INITIAL.
*         Transport log does not exist: not released or log deleted
            DELETE ddic_e071 INDEX lp_index.
            lp_deleted = abap_true.
          ELSE.
*         Now check in which environments the transport can be found
            LOOP AT st_request-cofile-systems INTO ls_systems.
*           For each environment, set the status icon:
              IF ls_systems-systemid = prd_system.
                READ TABLE ls_systems-steps INTO st_steps
                                            INDEX lines( ls_systems-steps ).
                IF sy-subrc = 0 AND st_steps-stepid <> '<'.
*               Transported to production, check not required on this
*               object. Delete all records for this object (not only
*               for this transport but for all transports)
                  DELETE ddic_e071 INDEX lp_index.
                  lp_deleted = abap_true.
                ENDIF.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.
      ENDIF.
*     Show the progress indicator
      IF lp_deleted = abap_false.
*       Only add counter if the line was not deleted...
        lp_counter = lp_counter + 1.
      ENDIF.
      lp_total = lines( ddic_e071 ).
      progress_indicator( im_counter = lp_counter
                          im_object  = ddic_e071_line-obj_name
                          im_total   = lp_total
                          im_text    = 'DDIC not transported...'(051)
                          im_flag    = ' ' ).
    ENDLOOP.
*   Rebuild ddic_objects list
    FREE ddic_objects.
    LOOP AT ddic_e071 INTO ddic_e071_line.
      APPEND ddic_e071_line-obj_name TO ddic_objects.
    ENDLOOP.
    SORT ddic_objects.
    DELETE ADJACENT DUPLICATES FROM ddic_objects.
*   Show the progress indicator
    cl_progress_indicator=>progress_indicate( i_text = 'Retrieving Where Used list'(052) ).

* Build the WHERE_USED list for all remaining objects
    FREE where_used.
    LOOP AT ddic_objects INTO ls_objects.
      FREE ddic_objects_sub.
      APPEND ls_objects TO ddic_objects_sub.
      CALL FUNCTION 'RS_EU_CROSSREF'
        EXPORTING
*         'DE'                     = Data element
          i_find_obj_cls           = 'DE'
          no_dialog                = 'X'
        IMPORTING
          o_scope_obj_cls          = lp_scope
          o_answer                 = lp_answer
        TABLES
          i_findstrings            = ddic_objects_sub
          o_founds                 = lt_where_used_sub
        EXCEPTIONS
          not_executed             = 1
          not_found                = 2
          illegal_object           = 3
          no_cross_for_this_object = 4
          batch                    = 5
          batchjob_error           = 6
          wrong_type               = 7
          object_not_exist         = 8
          OTHERS                   = 9.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
      APPEND LINES OF lt_where_used_sub TO where_used.
      FREE lt_where_used_sub.
    ENDLOOP.
* Remove all entries from the where used list that are not existing
* in tables DD01L, DD02L or DD04L
    LOOP AT where_used INTO where_used_line.
* DD01L (Domains)
      SELECT SINGLE domname
                    FROM dd01l INTO @lp_string
                    WHERE domname = @where_used_line-used_obj ##WARN_OK.
      IF sy-subrc <> 0.
* DD02L (SAP-tables)
        SELECT SINGLE tabname
                      FROM dd02l INTO @lp_string
                      WHERE tabname = @where_used_line-used_obj ##WARN_OK.
        IF sy-subrc <> 0.
* DD04L (Data elements)
          SELECT SINGLE rollname
                        FROM dd04l INTO @lp_string
                        WHERE rollname = @where_used_line-used_obj ##WARN_OK.
        ENDIF.
      ENDIF.
      IF sy-subrc <> 0.
        DELETE where_used INDEX sy-tabix.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_import_datetime_qas.
    DATA ls_systems TYPE ctslg_system.
    CLEAR ex_as4time.
    CLEAR ex_as4date.
*   Get the last date the object was imported
    CALL FUNCTION 'TR_READ_GLOBAL_INFO_OF_REQUEST'
      EXPORTING
        iv_trkorr = im_trkorr
      IMPORTING
        es_cofile = st_request-cofile.
    LOOP AT st_request-cofile-systems INTO ls_systems
                                      WHERE systemid = qas_system.
*     Get the latest import date:
      READ TABLE ls_systems-steps INTO st_steps
                                  INDEX lines( ls_systems-steps ).
      IF sy-subrc = 0.
        READ TABLE st_steps-actions INTO st_actions
                                    INDEX lines( st_steps-actions ).
        IF sy-subrc = 0.
          ex_as4time = st_actions-time.
          ex_as4date = st_actions-date.
        ENDIF.
      ENDIF.
    ENDLOOP.
    ex_return = sy-subrc.
  ENDMETHOD.

  METHOD exclude_all_tables.
    LOOP AT table_keys INTO table_keys_line.
      ls_excluded_objects-sign   = 'E'.
      ls_excluded_objects-option = 'EQ'.
      ls_excluded_objects-low    = table_keys_line-tabname.
      APPEND ls_excluded_objects TO excluded_objects.
    ENDLOOP.
  ENDMETHOD.

  METHOD ofc_goon.
    DATA lt_range_transports_to_add TYPE RANGE OF e070-trkorr.
    DATA ls_range_transports_to_add LIKE LINE OF lt_range_transports_to_add.
    DATA ls_row                     TYPE int4.
    IF rf_conflicts IS BOUND.
      rf_conflicts->close_screen( ).
*     Move the conflicts to a range. The transports in this range will
*     be added to the main list:
      FREE lt_range_transports_to_add.
      set_building_conflict_popup( abap_false ).
      CLEAR ls_range_transports_to_add.
      ls_range_transports_to_add-sign = 'I'.
      ls_range_transports_to_add-option = 'EQ'.
*     If row(s) are selected, use the table
      LOOP AT im_rows INTO ls_row.
        READ TABLE conflicts INTO conflict_line
                            INDEX ls_row.
        IF sy-subrc = 0.
          ls_range_transports_to_add-low = conflict_line-trkorr.
          APPEND ls_range_transports_to_add TO lt_range_transports_to_add.
        ENDIF.
      ENDLOOP.
*     Rows MUST be selected
      IF im_rows[] IS INITIAL.
        MESSAGE i000(db) WITH 'No rows selected: No transports will be added'(m06).
      ENDIF.
      IF lt_range_transports_to_add[] IS NOT INITIAL.
        add_to_main = get_added_objects( lt_range_transports_to_add ).
        get_additional_tp_info( CHANGING ch_table = add_to_main ).
        main_list = add_to_list( im_list   = main_list
                                 im_to_add = add_to_main ).
*       After the transports have been added, check if there are added
*       transports that are already in prd. If so, make them visible by
*       changing the prd icon to co_scrap.
        LOOP AT main_list INTO main_list_line
                                   WHERE prd    = co_okay
                                     AND trkorr IN lt_range_transports_to_add.
          main_list_line-prd = co_scrap.
          MODIFY main_list FROM main_list_line INDEX sy-tabix.
        ENDLOOP.
*       After the transports have been added, we need to check again
        flag_same_objects( CHANGING ch_main_list = main_list ).
        check_for_conflicts( CHANGING ch_main_list = main_list ).
        refresh_alv( ).
      ENDIF.
      FREE ch_table.
    ELSEIF rf_table_keys IS BOUND.
*     Not in the Conflicts Popup, but in the Table Key popup. Based on the user decision,
*     the tables that do NOT have to be checked, are added to the excluded object list.
*     If no tables are selected, all tables are excluded from the check.
*     If row(s) are selected, determine the tables to be check from the selected
*     rows. All rows that weren't selected will be added to the excluded object list.
      ch_table->close_screen( ).
      IF im_rows[] IS NOT INITIAL.
        LOOP AT table_keys INTO table_keys_line.
          IF NOT line_exists( im_rows[ table_line = sy-tabix ] ).
            ls_excluded_objects-sign   = 'E'.
            ls_excluded_objects-option = 'EQ'.
            ls_excluded_objects-low    = table_keys_line-tabname.
            APPEND ls_excluded_objects TO excluded_objects.
          ENDIF.
        ENDLOOP.
      ELSE.
*       If user pressed cancel, then add all tables to the excluded object list
        exclude_all_tables( ).
        MESSAGE i000(db) WITH 'No rows selected: Table keys will not be checked'(m07).
        check_tabkeys = abap_false.
      ENDIF.
      FREE ch_table.
    ENDIF.
  ENDMETHOD.

  METHOD ofc_abr.
    IF rf_table_keys IS BOUND.
      rf_table_keys->close_screen( ).
*     If user pressed cancel (Add all tables, do not check any)
      exclude_all_tables( ).
      MESSAGE i000(db) WITH 'Cancelled: Table keys will not be checked'(m09).
      FREE rf_table_keys.
      check_tabkeys = abap_false.
    ELSE.
      ch_conflicts->close_screen( ).
      FREE ch_conflicts.
    ENDIF.
  ENDMETHOD.

  METHOD ofc_ddic.
    DATA lp_answer           TYPE char01.
    DATA(lp_question) = VALUE string( ).
    IF where_used[] IS INITIAL.
      lp_question = 'This will take approx. 5-15 minutes... Continue?'(041).
    ELSE.
      lp_question = 'This has already been done. Do again?'(042).
    ENDIF.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Runtime Alert'(039)
        text_question         = lp_question
        text_button_1         = 'Yes'(037)
        icon_button_1         = 'ICON_OKAY'
        text_button_2         = 'No'(043)
        icon_button_2         = 'ICON_CANCEL'
        default_button        = '2'
        display_cancel_button = ' '
      IMPORTING
        answer                = lp_answer
      EXCEPTIONS
        text_not_found        = 1
        OTHERS                = 2.
    IF sy-subrc = 0 AND lp_answer = '1'.
      check_ddic = abap_true.
      set_ddic_objects( ).
      set_where_used( ).
    ENDIF.
    do_ddic_check( CHANGING ch_main_list = main_list ).
    refresh_alv( ).
    MESSAGE i000(db) WITH 'Data Dictionary check finished...'(m15).
  ENDMETHOD.

  METHOD ofc_add_tp.
    TYPES ty_sval TYPE sval.
    TYPES ty_field_tt TYPE STANDARD TABLE OF ty_sval.
    DATA lt_range_transports_to_add TYPE RANGE OF e070-trkorr.
    DATA ls_range_transports_to_add LIKE LINE OF lt_range_transports_to_add.
    DATA lt_fields           TYPE ty_field_tt.
    DATA ls_fields           TYPE sval.
    DATA lp_return           TYPE c.
    FREE lt_fields.
    CLEAR ls_fields.
    ls_fields-tabname   = 'E070'.
    ls_fields-fieldname = 'TRKORR'.
    APPEND ls_fields TO lt_fields.
    CALL FUNCTION 'POPUP_GET_VALUES_DB_CHECKED'
      EXPORTING
        popup_title     = 'Selected transports'(t01)
      IMPORTING
        returncode      = lp_return
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    CASE sy-subrc.
      WHEN 1.
        MESSAGE e000(db) WITH 'ERROR: ERROR_IN_FIELDS'(m08).
      WHEN 2.
        MESSAGE e000(db) WITH 'Error occurred'(029).
    ENDCASE.
*   Exit if cancelled:
    IF lp_return = 'A'.
      RETURN.
    ENDIF.
*   Move the conflicts to a range. The transports in this range will
*   be added to the main list:
    FREE lt_range_transports_to_add.
    CLEAR ls_range_transports_to_add.
    ls_range_transports_to_add-sign = 'I'.
    ls_range_transports_to_add-option = 'EQ'.
    READ TABLE lt_fields INTO ls_fields INDEX 1.          "#EC CI_SUBRC
    IF ls_fields-value IS INITIAL.
      RETURN.
    ENDIF.
*   Is it already in the list?
    IF line_exists( main_list[ trkorr = ls_fields-value(20) ] ).
      RETURN.
    ENDIF.
*   Add transport number to the internal table to add:
    ls_range_transports_to_add-low = ls_fields-value.
    APPEND ls_range_transports_to_add TO lt_range_transports_to_add.
    add_to_main = get_added_objects( lt_range_transports_to_add ).
    get_additional_tp_info( CHANGING ch_table = add_to_main ).
    main_list = add_to_list( im_list   = main_list
                             im_to_add = add_to_main ).
*   After the transports have been added, check if there are added
*   transports that are already in prd. If so, make them visible by
*   changing the prd icon to co_scrap.
    LOOP AT main_list INTO main_list_line
                     WHERE prd    = co_okay
                       AND trkorr IN lt_range_transports_to_add.
      main_list_line-prd = co_scrap.
      MODIFY main_list FROM main_list_line.
    ENDLOOP.
*   After the transports have been added, we need to check again
    flag_same_objects( CHANGING ch_main_list = main_list ).
    check_for_conflicts( CHANGING ch_main_list = main_list ).
    refresh_alv( ).
  ENDMETHOD.

  METHOD ofc_save.
*   Data declarations
    DATA lp_filelength       TYPE i ##NEEDED.
    DATA lp_filename         TYPE string.
*   Selected rows
    DATA lp_path             TYPE string.
    DATA lp_fullpath         TYPE string.
    DATA lp_desktop          TYPE string.
    DATA lp_timestamp        TYPE tzntstmps.
*   Build header
    tab_delimited = main_to_tab_delimited( main_list ).
*   Finding desktop
    cl_gui_frontend_services=>get_desktop_directory(
       CHANGING   desktop_directory = lp_desktop
       EXCEPTIONS
         cntl_error                 = 1
         error_no_gui               = 2
         not_supported_by_gui       = 3
         OTHERS                     = 4 ).
    IF sy-subrc <> 0.
      MESSAGE e001(00) WITH 'Desktop not found'(008) ##MG_MISSING.
    ENDIF.

    CONVERT DATE sy-datum TIME sy-uzeit
      INTO TIME STAMP lp_timestamp TIME ZONE sy-zonlo.
    DATA(lp_default_filename) = |{ lp_timestamp }|.
    CONCATENATE 'ZTCT-' lp_default_filename INTO lp_default_filename.

    DATA(lp_title) = |{ 'Save Transportlist'(009) }|.
    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        window_title         = lp_title
        default_extension    = 'TXT'
        default_file_name    = lp_default_filename
        initial_directory    = lp_desktop
      CHANGING
        filename             = lp_filename
        path                 = lp_path
        fullpath             = lp_fullpath
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4 ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

*   Display save dialog window
    cl_gui_frontend_services=>gui_download(
      EXPORTING
        filename                = lp_fullpath
        filetype                = 'ASC'
      IMPORTING
        filelength              = lp_filelength
      CHANGING
        data_tab                = tab_delimited
      EXCEPTIONS
        file_write_error        = 1
        no_batch                = 2
        gui_refuse_filetransfer = 3
        invalid_type            = 4
        no_authority            = 5
        unknown_error           = 6
        header_not_allowed      = 7
        separator_not_allowed   = 8
        filesize_not_allowed    = 9
        header_too_long         = 10
        dp_error_create         = 11
        dp_error_send           = 12
        dp_error_write          = 13
        unknown_dp_error        = 14
        access_denied           = 15
        dp_out_of_memory        = 16
        disk_full               = 17
        dp_timeout              = 18
        file_not_found          = 19
        dataprovider_exception  = 20
        control_flush_error     = 21
        not_supported_by_gui    = 22
        error_no_gui            = 23
        OTHERS                  = 24 ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDMETHOD.

  METHOD ofc_nconf.
    DATA lp_row_found        TYPE abap_bool.
    DATA lp_tabix            TYPE sytabix.
    CLEAR lp_row_found.
    lp_tabix = ch_cell-row + 1.
    LOOP AT main_list INTO main_list_line FROM lp_tabix.
      IF lp_row_found IS INITIAL
          AND main_list_line-warning_rank >= co_info_rank.
        ch_cell-row = sy-tabix.
        ch_cell-columnname = 'WARNING_LVL'.
        im_selections->set_current_cell( ch_cell ).
        lp_row_found = abap_true.
      ENDIF.
    ENDLOOP.
    IF lp_row_found IS INITIAL.
      LOOP AT main_list INTO main_list_line.
        IF lp_row_found IS INITIAL
            AND main_list_line-warning_rank >= co_info_rank.
          ch_cell-row = sy-tabix.
          ch_cell-columnname = 'WARNING_LVL'.
          im_selections->set_current_cell( ch_cell ).
          lp_row_found = abap_true.
        ENDIF.
      ENDLOOP.
      IF lp_row_found IS INITIAL.
        MESSAGE i000(db) WITH 'No next conflict found'(021).
      ENDIF.
    ENDIF.
    refresh_alv( ).
  ENDMETHOD.

  METHOD get_additional_info.
    DATA lt_stms_wbo_requests TYPE TABLE OF stms_wbo_request.
    DATA ls_stms_wbo_requests TYPE stms_wbo_request.
    DATA lt_tr_cofilines      TYPE tr_cofilines.
    DATA ls_tstrfcofil        TYPE tstrfcofil.
    DATA ls_systems           TYPE ctslg_system.
    DATA lv_prd_backup        TYPE icon_l4.
    ch_main_list_line-checked_by = sy-uname.
*   First get the descriptions (Status/Type/Project):
*   Retrieve texts for Status Description
    SELECT SINGLE ddtext
             FROM dd07t
             INTO @main_list_line-status_text
            WHERE domname    = 'TRSTATUS'
              AND ddlanguage = @co_langu
              AND domvalue_l = @ch_main_list_line-trstatus. "#EC CI_SEL_NESTED #EC CI_SUBRC
*   Retrieve texts for Description of request/task type
    SELECT SINGLE ddtext
             FROM dd07t
             INTO @ch_main_list_line-trfunction_txt
            WHERE domname    = 'TRFUNCTION'
              AND ddlanguage = @co_langu
              AND domvalue_l = @ch_main_list_line-trfunction. "#EC CI_SEL_NESTED #EC CI_SUBRC
*   Retrieve the project number (and description):
    SELECT SINGLE reference
           FROM e070a
           INTO @ch_main_list_line-project
          WHERE trkorr    = @ch_main_list_line-trkorr
            AND attribute = 'SAP_CTS_PROJECT'.       "#EC CI_SEL_NESTED
    IF sy-subrc = 0.
      SELECT SINGLE descriptn
               FROM ctsproject
               INTO @ch_main_list_line-project_descr  "#EC CI_SGLSELECT
              WHERE trkorr = @ch_main_list_line-project. "#EC CI_SEL_NESTED #EC CI_SUBRC
    ENDIF.
*   Check if transport has been released.
*   D - Modifiable
*   L - Modifiable, protected
*   A - Modifiable, protected
*   O - Release started
*   R - Released
*   N - Released (with import protection for repaired objects)
    FREE lt_stms_wbo_requests.
    READ TABLE tms_mgr_buffer INTO tms_mgr_buffer_line
               WITH TABLE KEY request       = ch_main_list_line-trkorr
                              target_system = dev_system.
    IF sy-subrc = 0.
      lt_stms_wbo_requests = tms_mgr_buffer_line-request_infos.
    ELSE.
      CALL FUNCTION 'TMS_MGR_READ_TRANSPORT_REQUEST'
        EXPORTING
          iv_request                 = ch_main_list_line-trkorr
          iv_target_system           = dev_system
          iv_header_only             = 'X'
          iv_monitor                 = ' '
        IMPORTING
          et_request_infos           = lt_stms_wbo_requests
        EXCEPTIONS
          read_config_failed         = 1
          table_of_requests_is_empty = 2
          system_not_available       = 3
          OTHERS                     = 4.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ELSE.
        tms_mgr_buffer_line-request       = ch_main_list_line-trkorr.
        tms_mgr_buffer_line-target_system = dev_system.
        tms_mgr_buffer_line-request_infos = lt_stms_wbo_requests.
        INSERT tms_mgr_buffer_line INTO TABLE tms_mgr_buffer.
      ENDIF.
    ENDIF.
    READ TABLE lt_stms_wbo_requests INDEX 1
                                    INTO ls_stms_wbo_requests. "#EC CI_SUBRC
*   Check if there is documentation available
    CLEAR ch_main_list_line-info.
    IF ls_stms_wbo_requests-docu[] IS NOT INITIAL.
      check_documentation( EXPORTING im_trkorr = ch_main_list_line-trkorr
                           CHANGING  ch_table  = ch_table ).
    ENDIF.
*   Check the returncode of this transport to QAS
    CALL FUNCTION 'STRF_READ_COFILE'
      EXPORTING
        iv_trkorr     = ch_main_list_line-trkorr
      TABLES
        tt_cofi_lines = lt_tr_cofilines
      EXCEPTIONS
        wrong_call    = 1
        no_info_found = 2
        OTHERS        = 3.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'I' NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
    READ TABLE lt_tr_cofilines INTO ls_tstrfcofil
                               WITH KEY tarsystem = qas_system
                                        function  = 'G'.  "#EC CI_SUBRC
    ch_main_list_line-retcode = ls_tstrfcofil-retcode.
    IF ls_stms_wbo_requests-e070-trstatus NA 'NR'.
      ch_main_list_line-warning_lvl  = co_alert.
      ch_main_list_line-warning_rank = co_alert1_rank.
      ch_main_list_line-warning_txt  = lp_alert1_text.
    ELSEIF ls_stms_wbo_requests-e070-trstatus = 'O'.
      ch_main_list_line-warning_lvl  = co_alert.
      ch_main_list_line-warning_rank = co_alert2_rank.
      ch_main_list_line-warning_txt  = lp_alert2_text.
    ELSE.
*     Retrieve the environments where the transport can be found.
*     Read the info of the request (transport log) to determine the
*     highest environment the transport has been moved to.
      CALL FUNCTION 'TR_READ_GLOBAL_INFO_OF_REQUEST'
        EXPORTING
          iv_trkorr = ch_main_list_line-trkorr
        IMPORTING
          es_cofile = st_request-cofile.

      IF st_request-cofile-systems IS INITIAL.
*       Transport log does not exist: not released or log deleted
        ch_main_list_line-warning_lvl  = co_alert.
        ch_main_list_line-warning_rank = co_alert0_rank.
        ch_main_list_line-warning_txt  = lp_alert0_text.
*       First check if the object can also be found further down in
*       the list. If it is, then THAT transport will be checked.
*       Because, even if this transport's log can't be read, if the
*       same object is found later in the list, that one will be
*       checked too. We don't have to worry about the fact that the
*       log does not exist for this transport.
        LOOP AT ch_table INTO line_found_in_list FROM im_indexinc
                        WHERE object     = ch_main_list_line-object
                          AND obj_name   = ch_main_list_line-obj_name
                          AND keyobject  = ch_main_list_line-keyobject
                          AND keyobjname = ch_main_list_line-keyobjname
                          AND tabkey     = ch_main_list_line-tabkey
                          AND prd        <> co_okay.
          EXIT.
        ENDLOOP.
        IF sy-subrc = 0.
          ch_main_list_line-warning_lvl  = co_hint.
          ch_main_list_line-warning_rank = co_hint3_rank.
          ch_main_list_line-warning_txt  = lp_hint3_text.
        ENDIF.
      ELSE.
*       Initialize environment fields. The environments will be
*       checked and updated with the correct environment later
        ch_main_list_line-dev = co_inact.
        ch_main_list_line-qas = co_inact.
*       If a transport is in production and marked for re-import, do not
*       change the SCRAP icon to the OKAY icon
        lv_prd_backup = ch_main_list_line-prd.
        ch_main_list_line-prd = co_inact.
*       Now check in which environments the transport can be found
        LOOP AT st_request-cofile-systems INTO ls_systems.
*         For each environment, set the status icon:
          CASE ls_systems-systemid.
            WHEN dev_system.
*             Green - Exists
              ch_main_list_line-dev = co_okay.
            WHEN qas_system.
*             Green - Exists
              ch_main_list_line-qas = co_okay.
*             Get the latest date/time stamp
              READ TABLE ls_systems-steps INTO st_steps
                                          INDEX lines( ls_systems-steps ).
              IF sy-subrc = 0.
                CHECK st_steps-stepid <> '<'.
                READ TABLE st_steps-actions INTO st_actions
                                            INDEX lines( st_steps-actions ).
                IF sy-subrc = 0.
                  ch_main_list_line-as4time = st_actions-time.
                  ch_main_list_line-as4date = st_actions-date.
                ENDIF.
              ENDIF.
            WHEN prd_system.
              READ TABLE ls_systems-steps INTO st_steps
                                         INDEX lines( ls_systems-steps ).
              IF sy-subrc = 0.
                CHECK st_steps-stepid <> '<'.
*               Green - Exists
                IF lv_prd_backup IS NOT INITIAL.
                  ch_main_list_line-prd = lv_prd_backup.
                ELSE.
                  ch_main_list_line-prd = co_okay.
                ENDIF.
              ENDIF.
          ENDCASE.
        ENDLOOP.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD go_back_months.
    DATA: BEGIN OF ls_dat,
            jjjj TYPE char4,
            mm   TYPE char2,
            tt   TYPE char2,
          END OF ls_dat.

    DATA: BEGIN OF ls_hdat,
            jjjj TYPE char4,
            mm   TYPE char2,
            tt   TYPE char2,
          END OF ls_hdat.

    WRITE: im_currdate+0(4) TO ls_dat-jjjj,
           im_currdate+4(2) TO ls_dat-mm,
           im_currdate+6(2) TO ls_dat-tt.
    DATA(lv_diffjjjj) = ( ls_dat-mm + ( - im_backmonths ) - 1 ) DIV 12.
    DATA(lv_newmm)    = ( ls_dat-mm + ( - im_backmonths ) - 1 ) MOD 12 + 1.
    ls_dat-jjjj = ls_dat-jjjj + lv_diffjjjj.

    IF lv_newmm < 10.
      WRITE '0'   TO ls_dat-mm+0(1).
      WRITE lv_newmm TO ls_dat-mm+1(1).
    ELSE.
      WRITE lv_newmm TO ls_dat-mm.
    ENDIF.
    IF ls_dat-tt > '28'.
      ls_hdat-tt   = '01'.
      lv_newmm  = ( ls_dat-mm ) MOD 12 + 1.
      ls_hdat-jjjj = ls_dat-jjjj + ( ( ls_dat-mm ) DIV 12 ).

      IF lv_newmm < 10.
        WRITE '0'      TO ls_hdat-mm+0(1).
        WRITE lv_newmm TO ls_hdat-mm+1(1).
      ELSE.
        WRITE lv_newmm TO ls_hdat-mm.
      ENDIF.

      IF ls_dat-tt = '31'.
        re_date = ls_hdat.
        re_date = re_date - 1.
      ELSEIF ls_dat-mm = '02'.
        re_date = ls_hdat.
        re_date = re_date - 1.
      ELSE.
        re_date = ls_dat.
      ENDIF.
    ELSE.
      re_date = ls_dat.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

*--------------------------------------------------------------------*
*       DATA SELECT
*--------------------------------------------------------------------*
START-OF-SELECTION.

  IF rf_ztct IS NOT BOUND.
    TRY.
        rf_ztct = NEW #( ).
      CATCH cx_root INTO rf_root ##CATCH_ALL.
        tp_msg = rf_root->get_text( ).
        CONCATENATE 'ERROR:'(038) tp_msg INTO tp_msg SEPARATED BY space.
        MESSAGE tp_msg TYPE 'E'.
    ENDTRY.
  ENDIF.

  tp_prefix = rf_ztct->get_tp_prefix( p_dev ).

  IF p_sel = abap_true.
    tp_process_type = 1.
  ELSE.
    tp_process_type = 3.
  ENDIF.

  IF tp_process_type = 1.
*   Get transports
    cl_progress_indicator=>progress_indicate( i_text = 'Selecting data...'(014) ).
*   Join over E070, E071:
*   Description is read later to prevent complicated join and
*   increased runtime
    SELECT 'I' AS sign, 'EQ' AS option, a~trkorr AS low, ' ' AS high
         INTO TABLE @ta_trkorr_range
         FROM e070 AS a JOIN e071 AS b
           ON a~trkorr   = b~trkorr
        WHERE a~trkorr   IN @s_korr
          AND a~as4user  IN @s_user
          AND a~as4date  IN @s_date
          AND b~obj_name IN @s_exobj
          AND strkorr    = ''
          AND a~trkorr   LIKE @tp_prefix
          AND a~trkorr   IN @lt_range_project_trkorrs
          AND ( pgmid    = 'LIMU' OR
                pgmid    = 'R3TR' ).

*   Read transport description:
    IF sy-subrc = 0 AND ta_trkorr_range[] IS NOT INITIAL.
      LOOP AT ta_trkorr_range INTO st_trkorr_range.
        tp_tabix = sy-tabix.
*       Check if the description contains the search string
        SELECT as4text FROM e07t INTO TABLE @ta_transport_descr
                       WHERE trkorr = @st_trkorr_range-low ##WARN_OK.
        IF sy-subrc = 0.
          tp_descr_exists = abap_false.
          LOOP AT ta_transport_descr INTO tp_transport_descr.
            IF p_str CS '*'.
              IF tp_transport_descr CP p_str.
                tp_descr_exists = abap_true.
              ENDIF.
            ELSEIF tp_transport_descr CS p_str.
              tp_descr_exists = abap_true.
            ENDIF.
          ENDLOOP.
          IF tp_descr_exists = abap_false.
            DELETE ta_trkorr_range INDEX tp_tabix.
            CONTINUE.
          ENDIF.
        ENDIF.
*       Check if the project is in the selection range
        SELECT SINGLE reference FROM e070a
               INTO @tp_project_reference
              WHERE trkorr = @st_trkorr_range-low
                AND attribute = 'SAP_CTS_PROJECT'.        "#EC CI_SUBRC
        IF sy-subrc = 0 AND tp_project_reference NOT IN s_proj.
          DELETE ta_trkorr_range INDEX sy-tabix.
        ENDIF.
      ENDLOOP.
      SORT ta_trkorr_range.
      DELETE ADJACENT DUPLICATES FROM ta_trkorr_range.
    ENDIF.
  ENDIF.

  ta_project_range[] = s_proj[].
  lt_excluded_objects[] = s_exobj[].

END-OF-SELECTION.

*--------------------------------------------------------------------*
*       Main program
*--------------------------------------------------------------------*
  IF ta_trkorr_range IS INITIAL AND tp_process_type = 1.
    MESSAGE i000(db) DISPLAY LIKE 'E'
                     WITH 'No transports found...'(m13).
  ELSE.
    PERFORM init_ztct.
    rf_ztct->execute( ).
  ENDIF.

*&---------------------------------------------------------------------*
*&      Form  INIT_ZTCT
*&---------------------------------------------------------------------*
FORM init_ztct.
  rf_ztct->set_check_flag( p_sel ).
  rf_ztct->set_check_tabkeys( p_chkky ).
  rf_ztct->set_clear_checked( p_chd ).
  rf_ztct->set_buffer_chk( p_buff ).
  rf_ztct->set_buffer_remove_tp( p_buffd ).
  rf_ztct->set_skiplive( p_noprd ).
  rf_ztct->set_user_layout( p_user ).
  rf_ztct->set_trkorr_range( ta_trkorr_range ).
  rf_ztct->set_project_range( ta_project_range ).
  rf_ztct->set_excluded_objects( lt_excluded_objects ).
  rf_ztct->set_process_type( tp_process_type ).
  rf_ztct->set_filename( p_file ).
  rf_ztct->set_systems( im_dev_system = p_dev
                        im_qas_system = p_qas
                        im_prd_system = p_prd ).
ENDFORM.
