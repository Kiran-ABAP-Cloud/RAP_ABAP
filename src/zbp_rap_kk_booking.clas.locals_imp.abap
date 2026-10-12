CLASS lhc_Booking DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS earlynumbering_cba_Bookingsupp FOR NUMBERING
       entities FOR CREATE Booking\_Bookingsuppl.

ENDCLASS.

CLASS lhc_Booking IMPLEMENTATION.

  METHOD earlynumbering_cba_Bookingsupp.
    DATA: max_book_suppl_id TYPE /dmo/booking_supplement_id.

    "Step 1: Get all the travel request and their booking supplements
    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
         ENTITY booking BY \_BookingSuppl
         FROM CORRESPONDING #( entities )
         LINK DATA(lt_booking_suppl).

    "STep 2: Cases to handle for assigning unique Booking Supplement ID
    "1001, 1002, 1005
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<booking_group>) GROUP BY <booking_group>-%tky-BookingId.

      "Step 3: Loop at the specific booking supplements of every unique Booking Id
      "Get the highest assigned (already) supplement ID number
      LOOP AT lt_booking_suppl INTO DATA(ls_book_suppl) USING KEY entity
                          WHERE source-TravelId = <booking_group>-TravelId
                          AND   source-BookingId = <booking_group>-BookingId.
        "Determine the already created Booking Id which is maximum
        IF max_book_suppl_id < ls_book_suppl-target-BookingId.
          max_book_suppl_id = ls_book_suppl-target-BookingId.
        ENDIF.
      ENDLOOP.

      "Get the assigned supplement id for incoming request
      LOOP AT entities INTO DATA(ls_entity) WHERE TravelId = <booking_group>-TravelId
                                             AND  BookingId = <booking_group>-BookingId.
        LOOP AT ls_entity-%target INTO DATA(ls_target).
          IF max_book_suppl_id < ls_target-BookingSupplementId.
            max_book_suppl_id = ls_target-BookingSupplementId.
          ENDIF.
        ENDLOOP.
      ENDLOOP.

      "STep 4: Loop over all the entities of travel with same Travel is and increment the max booking Id
      LOOP AT entities ASSIGNING FIELD-SYMBOL(<booking>) USING KEY entity
                                              WHERE TravelId = <booking_group>-TravelId
                                                AND  BookingId = <booking_group>-BookingId.
        "Step 5: Increment the Booking supplement Id + 1 and assign the new id
        LOOP AT <booking>-%target ASSIGNING FIELD-SYMBOL(<booksuppl_wo_number>).
          APPEND CORRESPONDING #( <booksuppl_wo_number> ) TO mapped-booksuppl
                                             ASSIGNING FIELD-SYMBOL(<mapped_book_suppl>).

          "Determine the already created Booking supplement Id which is maximum
          "Assigning the +1 as new Booking Id
          IF <mapped_book_suppl>-BookingSupplementId IS INITIAL.
            max_book_suppl_id += 1.
            <mapped_book_suppl>-BookingSupplementId = max_book_suppl_id.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
