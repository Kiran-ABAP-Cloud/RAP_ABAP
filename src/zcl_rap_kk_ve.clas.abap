CLASS zcl_rap_kk_ve DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_sadl_exit .
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rap_kk_ve IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~calculate.
  "Mention these two fields in MDE file to display in Fiori UI
    check it_original_data is not initial.
    data: lt_calc_data type STANDARD TABLE OF zrap_kk_travel_processor WITH DEFAULT KEY,
          lv_rate      type p DECIMALS 2 value '0.025'.

    lt_calc_data = CORRESPONDING #( it_original_data ).

    LOOP AT lt_calc_data ASSIGNING FIELD-SYMBOL(<fs_calc_data>).
        <fs_calc_data>-CO2Tax = <fs_calc_data>-TotalPrice * lv_rate.
        <fs_calc_data>-dayOfFlight = 'Sunday'.
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_calc_data ).

  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
  ENDMETHOD.
ENDCLASS.
