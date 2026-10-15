CLASS lhc_BookSuppl DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS CalcTotalPriceSuppl FOR DETERMINE ON MODIFY
       keys FOR BookSuppl~CalcTotalPriceSuppl.

ENDCLASS.

CLASS lhc_BookSuppl IMPLEMENTATION.

  METHOD CalcTotalPriceSuppl.
  "How to call an action using the EML
    MODIFY ENTITIES OF zrap_kk_travel IN LOCAL MODE
     ENTITY Travel
     EXECUTE recCalcTotalPrice
     FROM CORRESPONDING #( keys ).
  ENDMETHOD.

ENDCLASS.
