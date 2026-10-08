CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Travel RESULT result.
    METHODS earlynumbering_create FOR NUMBERING
       entities FOR CREATE travel.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_instance_authorizations.
*Authority Check can be implemented
  ENDMETHOD.

  METHOD earlynumbering_create.
    DATA: entity        TYPE STRUCTURE FOR CREATE zrap_kk_travel,
          travel_id_max TYPE /dmo/travel_id.

    " Step 1: Ensure that the travel id is not passed by user, so we can generate id
    LOOP AT entities INTO entity WHERE travelid IS NOT INITIAL.
      APPEND CORRESPONDING #( entity ) TO mapped-travel.
    ENDLOOP.

    "STep 2: lets take all travel request data in another copy
    " filter out record which has travel id, only keep where travel id is blank
    DATA(entities_wo_travelid) = entities.
    DELETE entities_wo_travelid WHERE travelid IS NOT INITIAL.

    "Step 3: Lets use SNRO generator to create travel id
    "Example current no 422, I want three - 426
    "426-1 =425, 425-1 =424, 424-1 =423
    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr       = '01'
            object            = CONV #( '/DMO/TRAVL' )
            quantity          = CONV #( lines( entities_wo_travelid ) )
          IMPORTING
            number            = DATA(number_range_key)
            returncode        = DATA(number_range_return_code)
            returned_quantity = DATA(number_range_returned_quantity)
        ).
      CATCH cx_number_ranges INTO DATA(lx_number_ranges).
        "Step4: If there is a dump inside, we will just fill failed and reported
        LOOP AT entities_wo_travelid INTO entity.
          APPEND VALUE #( %cid = entity-%cid %key = entity-%key %msg = lx_number_ranges ) TO reported-travel.
          APPEND VALUE #( %cid = entity-%cid %key = entity-%key ) TO failed-travel.
        ENDLOOP.
    ENDTRY.
    "Step 5: Handle special cases if no. range exhausted, about to get exhausted
    CASE number_range_return_code.
      WHEN '1'.
        "About to exhaust 99% numbers finished
        LOOP AT entities_wo_travelid INTO entity.
          APPEND VALUE #( %cid = entity-%cid %key = entity-%key %msg = NEW /dmo/cm_flight_messages(
                                                                                   textid = /dmo/cm_flight_messages=>number_range_depleted
                                                                                   severity = if_abap_behv_message=>severity-warning ) ) TO reported-travel.
        ENDLOOP.

      WHEN '2' OR '3'.
        "last number returned or no. range exhausted
        LOOP AT entities_wo_travelid INTO entity.
          APPEND VALUE #( %cid = entity-%cid %key = entity-%key %msg = NEW /dmo/cm_flight_messages(
                                                                                   textid = /dmo/cm_flight_messages=>not_sufficient_numbers
                                                                                   severity = if_abap_behv_message=>severity-warning ) ) TO reported-travel.

          APPEND VALUE #( %cid = entity-%cid %key = entity-%key %fail-cause = if_abap_behv=>cause-conflict ) TO failed-travel.

        ENDLOOP.
    ENDCASE.

    "Step 6: Final check for all numbers
    ASSERT number_range_returned_quantity = lines( entities_wo_travelid ).

    "Step 7 Loop over the incoming data and assign the travel id by incrementing it
    " Send the data wrapped to RAP framework
    travel_id_max = number_range_key - number_range_returned_quantity.

    LOOP AT entities_wo_travelid INTO entity.
      travel_id_max += 1.
      entity-TravelId = travel_id_max.

      APPEND VALUE #( %cid = entity-%cid %key = entity-%key ) TO mapped-travel.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
