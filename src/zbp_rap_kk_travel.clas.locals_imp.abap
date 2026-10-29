CLASS lsc_zrap_kk_travel DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zrap_kk_travel IMPLEMENTATION.

  METHOD save_modified.
    "Addition save during update of Travel when customer Id or Agency Id got changed

    DATA: lt_log_data   TYPE STANDARD TABLE OF /dmo/log_travel,
          lt_final_data TYPE STANDARD TABLE OF /dmo/log_travel.
    IF update-travel IS NOT INITIAL.

      "Get all changes in our local table done by user
      lt_log_data = CORRESPONDING #( update-travel MAPPING travel_id = TravelId ).

      LOOP AT update-travel ASSIGNING FIELD-SYMBOL(<fs_changes>).
        ASSIGN lt_log_data[ travel_id = <fs_changes>-TravelId ]
                TO FIELD-SYMBOL(<travel_log_db>).

        GET TIME STAMP FIELD <travel_log_db>-Created_At.

        IF <fs_changes>-%control-CustomerId = if_abap_behv=>mk-on.
          <travel_log_db>-change_id = cl_system_uuid=>create_uuid_x16_static( ).
          <travel_log_db>-changed_field_name = 'kiran_customer'.
          <travel_log_db>-changed_value = <fs_changes>-CustomerId.
          <travel_log_db>-changing_operation = 'update'.
          APPEND <travel_log_db> TO lt_final_data.
        ENDIF.


        IF <fs_changes>-%control-AgencyId = if_abap_behv=>mk-on.
          <travel_log_db>-change_id = cl_system_uuid=>create_uuid_x16_static( ).
          <travel_log_db>-changed_field_name = 'kiran_agency'.
          <travel_log_db>-changed_value = <fs_changes>-AgencyId.
          <travel_log_db>-changing_operation = 'update'.
          APPEND <travel_log_db> TO lt_final_data.
        ENDIF.
      ENDLOOP.
      INSERT /dmo/log_travel FROM TABLE @lt_final_data.

    ENDIF.

  ENDMETHOD.

ENDCLASS.

CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Travel RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      keys REQUEST requested_features FOR travel RESULT result.
    METHODS copytravel FOR MODIFY
       keys FOR ACTION travel~copytravel.
    METHODS reccalctotalprice FOR MODIFY
       keys FOR ACTION travel~reccalctotalprice.
    METHODS calctotalprice FOR DETERMINE ON MODIFY
       keys FOR travel~calctotalprice.
    METHODS validateheaderdata FOR VALIDATE ON SAVE
       keys FOR travel~validateheaderdata.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR travel RESULT result.
    METHODS precheck_create FOR PRECHECK
       entities FOR CREATE travel.

    METHODS precheck_update FOR PRECHECK
       entities FOR UPDATE travel.
    METHODS accepttravel FOR MODIFY
       keys FOR ACTION travel~accepttravel RESULT result.

    METHODS rejecttravel FOR MODIFY
       keys FOR ACTION travel~rejecttravel RESULT result.
    METHODS earlynumbering_cba_booking FOR NUMBERING
       entities FOR CREATE travel\_booking.
    METHODS earlynumbering_create FOR NUMBERING
       entities FOR CREATE travel.

    " Declare data types for input and output for my reuse method
    TYPES: t_entity_create   TYPE TABLE FOR CREATE zrap_kk_travel,
           t_entity_update   TYPE TABLE FOR UPDATE zrap_kk_travel,
           t_entity_reported TYPE TABLE FOR REPORTED zrap_kk_travel,
           t_entity_failed   TYPE TABLE FOR FAILED zrap_kk_travel.

    "reusable method
    METHODS precheck_kiran_reuse
      IMPORTING
        entity_u TYPE t_entity_update OPTIONAL
        entity_c TYPE t_entity_create OPTIONAL
      EXPORTING
        reported TYPE t_entity_reported
        failed   TYPE t_entity_failed.


ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    "Case study is only allow to update cancelled travel request if it is only a manager otherwise don't allow to modify
*Authority Check can be implemented
    "STep 1: Define a return data structure for return table
    DATA ls_return LIKE LINE OF result.

    "STep 2: Read the instance of the BO, read overallstatus
    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
         ENTITY travel
         FIELDS ( travelid overallstatus )
         WITH CORRESPONDING #( keys )
         RESULT DATA(lt_travel)
         FAILED DATA(lt_failed).

    "STep 3: check if the status is CANCELLED
    LOOP AT lt_travel INTO DATA(ls_travel).
      DATA(lv_auth) = abap_false.
      IF ( ls_travel-overallstatus = 'X' ).
        AUTHORITY-CHECK OBJECT 'ZRAP_KK'
                ID 'ACTVT'         FIELD '02'.
        IF sy-subrc EQ 0. "Pass user is manager
          lv_auth = abap_true.
        ENDIF.
      ELSE.
        lv_auth = abap_true.
      ENDIF.

      ls_return = VALUE #( travelid = ls_travel-travelid
            "Odata V4 update
                           %action-edit = COND #(
                                                WHEN lv_auth EQ abap_false
                                                    THEN if_abap_behv=>auth-unauthorized
                                                    ELSE if_abap_behv=>auth-allowed
                                                )

            "Odata V2 update
                            %update = COND #(
                                                WHEN lv_auth EQ abap_false
                                                    THEN if_abap_behv=>auth-unauthorized
                                                    ELSE if_abap_behv=>auth-allowed
                                                )
                           ).
      APPEND ls_return TO result.
    ENDLOOP.
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

      APPEND VALUE #( %cid = entity-%cid %key = entity-%key
                      %is_draft = entity-%is_draft ) TO mapped-travel.
    ENDLOOP.

  ENDMETHOD.

  METHOD earlynumbering_cba_Booking.
    DATA: max_booking_id TYPE /dmo/booking_id.

    "Step 1: Get all the travel request and their bookings
    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
                ENTITY travel BY \_Booking
                FROM CORRESPONDING #( entities )
                LINK DATA(lt_bookings).

    "STep 2: Cases to handle for assigning unique Booking ID
    "1001, 1002, 1005
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<travel_group>) GROUP BY <travel_group>-TravelId.

      "Step 3: Loop at the specific booking of every unique Travel Id
      "Pass 1 - 10,20
      "Pass 2 - 10
      "Pass 3 - 40,50
      LOOP AT lt_bookings INTO DATA(ls_bookings) USING KEY entity
                          WHERE source-TravelId = <travel_group>-TravelId.
        "Determine the already created Booking Id which is maximum
        IF max_booking_id < ls_bookings-target-BookingId.
          max_booking_id = ls_bookings-target-BookingId.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    "STep 4: Loop over all the entities of travel with same Travel is and increment the max booking Id
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<travel>) GROUP BY <travel_group>-TravelId.

      "Step 5: Increment the Booking Id + 10 and assign the new id
      LOOP AT <travel>-%target ASSIGNING FIELD-SYMBOL(<travel_wo_number>).
        APPEND CORRESPONDING #( <travel_wo_number> ) TO mapped-booking
                                           ASSIGNING FIELD-SYMBOL(<mapped_booking>).

        "Determine the already created Booking Id which is maximum
        "Assigning the +10 as new Booking Id
        IF <mapped_booking>-BookingId IS INITIAL.
          max_booking_id += 10.
          <mapped_booking>-BookingId = max_booking_id.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    "Use Case: Check the status of the current travel request
    " if cancelled, disable the booking creation

    "Step 1: EML to read the travel status
    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
         ENTITY Travel
         FIELDS ( TravelId OverallStatus )
         WITH CORRESPONDING #( keys )
         RESULT DATA(lt_travel)
         FAILED DATA(lt_failed).

    "STep 2: Return the result with booking creation is possible or not
    READ TABLE lt_travel INTO DATA(ls_travel) INDEX 1.
    IF ( ls_travel-OverallStatus = 'X' ).
      DATA(lv_allow) = if_abap_behv=>fc-o-disabled.
    ELSE.
      lv_allow = if_abap_behv=>fc-o-enabled.
    ENDIF.


    result = VALUE #( FOR travel IN lt_travel ( %tky = travel-%tky
                                                %assoc-_Booking = lv_allow
                                                %features-%action-acceptTravel =
                                                cond #( when travel-OverallStatus = 'A'
                                                            then if_abap_behv=>fc-o-disabled
                                                            else if_abap_behv=>fc-o-enabled )

                                                %features-%action-rejectTravel =
                                                 cond #( when travel-OverallStatus = 'X'
                                                            then if_abap_behv=>fc-o-disabled
                                                            else if_abap_behv=>fc-o-enabled )
                                                ) ).


  ENDMETHOD.

  METHOD copyTravel.
    "Shallow copy = Header
    "Deep Copy = Header, Items, Sub Items
    "Step 1: Declare data to store new records
    DATA: travels       TYPE TABLE FOR CREATE zrap_kk_travel\\travel,
          bookings_cba  TYPE TABLE FOR CREATE zrap_kk_travel\\travel\_Booking,
          booksuppl_cba TYPE TABLE FOR CREATE zrap_kk_travel\\Booking\_BookingSuppl.

    "Step 1: Remove the travel instance with blank %cid
    READ TABLE keys WITH KEY %cid = '' INTO DATA(key_with_initial_cid).
    ASSERT key_with_initial_cid IS INITIAL.

    "Step 2: Read all the existing data of travel, booking, supplement
    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
    ENTITY Travel
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(travel_read_result)
    FAILED failed.

    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
    ENTITY Travel BY \_Booking
    ALL FIELDS WITH CORRESPONDING #( travel_read_result )
    RESULT DATA(book_read_result)
    FAILED failed.

    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
    ENTITY booking BY \_BookingSuppl
    ALL FIELDS WITH CORRESPONDING #( book_read_result )
    RESULT DATA(booksuppl_read_result)
    FAILED failed.

    "Step 3: Prepare the data to be inserted in DB
    LOOP AT travel_read_result ASSIGNING FIELD-SYMBOL(<travel>).
      "Travel Data prepare
      APPEND VALUE #( %cid = keys[ %tky = <travel>-%tky ]-%cid
                      %data = CORRESPONDING #( <travel> EXCEPT travelid )
                     ) TO travels ASSIGNING FIELD-SYMBOL(<new_travel>).
      <new_travel>-BeginDate = cl_abap_context_info=>get_system_date( ).
      <new_travel>-EndDate = cl_abap_context_info=>get_system_date( ) + 30.
      <new_travel>-OverallStatus = 'N'.

      "Booking Data preparation
      "We have to pass %cid_ref to tell system, that the bookings belongs to which travel request
      " A record was inserted in itab for booking
      APPEND VALUE #( %cid_ref = keys[ %tky = <travel>-%tky ]-%cid
                     ) TO bookings_cba ASSIGNING FIELD-SYMBOL(<booking_cba>).

      "Prepare all the bookings from existing request which needs to be copied
      LOOP AT book_read_result ASSIGNING FIELD-SYMBOL(<booking>) WHERE travelid = <travel>-travelid.
        "Lets pass a unique booking cid - concatenate the CID of travel with BookingId of existing travel
        APPEND VALUE #( %cid = keys[ %tky = <travel>-%tky ]-%cid && <booking>-BookingId
                        %data = CORRESPONDING #( book_read_result[ %tky = <booking>-%tky ] EXCEPT travelid ) )
                      TO <booking_cba>-%target ASSIGNING FIELD-SYMBOL(<new_booking>).
        <new_booking>-BookingStatus = 'N'.

        "STart of supplement
        "We have to pass %cid_ref to tell system, that the bookings belongs to which travel request
        " A record was inserted in itab for booking
        APPEND VALUE #( %cid_ref = keys[ %tky = <travel>-%tky ]-%cid && <booking>-BookingId
                       ) TO booksuppl_cba ASSIGNING FIELD-SYMBOL(<booksuppl_cba>).

        "Prepare all the bookings from existing request which needs to be copied
        LOOP AT booksuppl_read_result ASSIGNING FIELD-SYMBOL(<booksuppl>) WHERE travelid = <travel>-travelid
                                                                           AND  BookingId = <booking>-BookingId.
          "Lets pass a unique booking cid - concatenate the CID of travel with BookingId of existing travel
          APPEND VALUE #( %cid = keys[ %tky = <travel>-%tky ]-%cid && <booking>-BookingId && <booksuppl>-BookingSupplementId
                          %data = CORRESPONDING #( booksuppl_read_result[ %tky = <booksuppl>-%tky ] EXCEPT travelid bookingid ) )
                        TO <booksuppl_cba>-%target.
          "End of Supplement
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

    "STep 4: Insert data in DB using EML
    MODIFY ENTITIES OF zrap_kk_travel IN LOCAL MODE
        ENTITY travel
        CREATE FIELDS ( agencyid customerid begindate enddate bookingfee totalprice currencycode overallstatus )
        WITH travels
        CREATE BY \_Booking FIELDS ( bookingid bookingdate customerid CarrierId connectionid flightdate flightprice currencycode bookingstatus )
        WITH bookings_cba
        ENTITY Booking
        CREATE BY \_BookingSuppl FIELDS ( BookingSupplementId SupplementId Price CurrencyCode )
        WITH booksuppl_cba
        MAPPED DATA(mapped_data)
        FAILED failed
        REPORTED reported.

    mapped = mapped_data.

  ENDMETHOD.

  METHOD recCalcTotalPrice.
    "Define a structure where we can store all the booking fees and currency code
    TYPES: BEGIN OF ty_total_cost,
             amount        TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_total_cost.

    DATA: amounts_per_currencycode TYPE STANDARD TABLE OF ty_total_cost,
          ls_header_curr           TYPE /dmo/currency_code.

    "Read all the travel instances, bookings and supplement
    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
      ENTITY Travel
      FIELDS ( bookingfee CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(travel)
      FAILED failed.

    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
    ENTITY Travel BY \_Booking
    FIELDS ( FlightPrice CurrencyCode ) WITH CORRESPONDING #( travel )
    RESULT DATA(booking)
    FAILED failed.

    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
    ENTITY booking BY \_BookingSuppl
    FIELDS ( Price CurrencyCode ) WITH CORRESPONDING #( booking )
    RESULT DATA(booksuppl)
    FAILED failed.

    "Delete records where currencycode is empty, optionally throw error
    DELETE travel WHERE CurrencyCode IS INITIAL.
    DELETE booking WHERE CurrencyCode IS INITIAL.
    DELETE booksuppl WHERE CurrencyCode IS INITIAL.

    "Loop at header, item and items child total all the amounts in itab for common currency
    LOOP AT travel ASSIGNING FIELD-SYMBOL(<fs_travel>).
      amounts_per_currencycode = VALUE #( ( amount = <fs_travel>-bookingfee currency_code = <fs_travel>-currencycode )  ).
      ls_header_curr =  <fs_travel>-currencycode.

      LOOP AT booking INTO DATA(wa_booking) WHERE travelid = <fs_travel>-travelid.
        "And add all numeric column values by comparing non numeric values
        COLLECT VALUE ty_total_cost( amount = wa_booking-flightprice currency_code = wa_booking-currencycode )
                      INTO amounts_per_currencycode.
        LOOP AT booksuppl INTO DATA(wa_booksuppl) WHERE travelid = wa_booking-travelid
                                                   AND  bookingid = wa_booking-bookingid.

          COLLECT VALUE ty_total_cost( amount = wa_booksuppl-price currency_code = wa_booksuppl-currencycode )
                        INTO amounts_per_currencycode.
        ENDLOOP.
      ENDLOOP.
      CLEAR <fs_travel>-totalprice.
    ENDLOOP.


    "Compare the currency of Booking and Supplement with header currency
    LOOP AT amounts_per_currencycode INTO DATA(ls_amount_per_currency).
      "If it does not match, perform currency conversion
      IF ls_amount_per_currency-currency_code = ls_header_curr.
        <fs_travel>-totalprice += ls_amount_per_currency-amount.
      ELSE.
        /dmo/cl_flight_amdp=>convert_currency(
          EXPORTING
            iv_amount               = ls_amount_per_currency-amount
            iv_currency_code_source = ls_amount_per_currency-currency_code
            iv_currency_code_target = ls_header_curr
            iv_exchange_rate_date   = cl_abap_context_info=>get_system_date( )
          IMPORTING
            ev_amount               = DATA(total_amt)
        ).

        <fs_travel>-totalprice += total_amt.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zrap_kk_travel IN LOCAL MODE
           ENTITY travel
           UPDATE FIELDS ( totalprice )
           WITH CORRESPONDING #( travel ).

  ENDMETHOD.

  METHOD CalcTotalPrice.

    "How to call an action using the EML
    MODIFY ENTITIES OF zrap_kk_travel IN LOCAL MODE
     ENTITY Travel
     EXECUTE recCalcTotalPrice
     FROM CORRESPONDING #( keys ).
  ENDMETHOD.

  METHOD validateHeaderData.
    "STep 1: Read the data of incoming request from EML
    READ ENTITIES OF zrap_kk_travel IN LOCAL MODE
        ENTITY Travel
            FIELDS (  AgencyId CustomerId BeginDate EndDate )
            WITH CORRESPONDING #( keys )
            RESULT DATA(lt_travel).

    "STep 2: Declare sorted table to hold customer ids and agency id
    DATA: lt_customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id,
          lt_agency    TYPE SORTED TABLE OF /dmo/agency WITH UNIQUE KEY agency_id.


    "Step 3: Extract the unique customer and agency ids from travel data
    lt_customers = CORRESPONDING #( lt_travel DISCARDING DUPLICATES MAPPING customer_id = CustomerId EXCEPT * ).
    lt_agency    = CORRESPONDING #( lt_travel DISCARDING DUPLICATES MAPPING agency_id = agencyid EXCEPT * ).

    DELETE lt_customers WHERE customer_id IS INITIAL.
    DELETE lt_agency WHERE agency_id IS INITIAL.

    "Step 4: Extract the Customer and Agency data from database based on Travel Data
    IF lt_customers IS NOT INITIAL.
      SELECT FROM /dmo/customer FIELDS customer_id
             FOR ALL ENTRIES IN @lt_customers
              WHERE customer_id = @lt_customers-customer_id
              INTO TABLE @DATA(lt_cust_db).
    ENDIF.

    IF lt_agency IS NOT INITIAL.
      SELECT FROM /dmo/agency FIELDS agency_id
          FOR ALL ENTRIES IN @lt_agency
          WHERE agency_id = @lt_agency-agency_id
          INTO TABLE @DATA(lt_agency_db).
    ENDIF.

    "STep 5: Loop at incoming data to validate customer and agency one by one
    LOOP AT lt_travel INTO DATA(ls_travel).
      "check if customer id is blank OR
      "If in the DB customer does not exist
      IF ( ls_travel-CustomerId IS INITIAL OR NOT line_exists( lt_cust_db[ customer_id = ls_travel-CustomerId ]  ) ).
        APPEND VALUE #( %tky = ls_travel-%tky ) TO failed-travel.
        APPEND VALUE #( %tky = ls_travel-%tky
                        %element-customerid = if_abap_behv=>mk-on
                        %msg = NEW /dmo/cm_flight_messages(
                                                       textid = /dmo/cm_flight_messages=>customer_unkown
                                                       customer_id = ls_travel-customerid
                                                       severity = if_abap_behv_message=>severity-error
                                                       )
                       ) TO reported-travel.

      ENDIF.

      "check if Agency id is blank OR
      "If in the DB Agency does not exist
      IF ( ls_travel-AgencyId IS INITIAL OR NOT line_exists( lt_agency_db[ agency_id = ls_travel-AgencyId ]  ) ).
        APPEND VALUE #( %tky = ls_travel-%tky ) TO failed-travel.
        APPEND VALUE #( %tky = ls_travel-%tky
                        %element-agencyid = if_abap_behv=>mk-on
                        %msg = NEW /dmo/cm_flight_messages(
                                                       textid = /dmo/cm_flight_messages=>agency_unkown
                                                       agency_id = ls_travel-agencyid
                                                       severity = if_abap_behv_message=>severity-error
                                                       )
                       ) TO reported-travel.

      ENDIF.
      "Check if the travel start date is >= today's date
      "Travel end date must be > begin date
      "Travel begin and end date must not be initial
    ENDLOOP.

  ENDMETHOD.


  METHOD precheck_kiran_reuse.
    "step 1: data declaration
    DATA: entities  TYPE t_entity_update,
          operation TYPE if_abap_behv=>t_char01,
          agencies  TYPE SORTED TABLE OF /dmo/agency WITH UNIQUE KEY agency_id,
          customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    "Step 2: check atleast either create data or update data was passed
    ASSERT NOT ( entity_c IS INITIAL EQUIV entity_u IS INITIAL ).

    "Step 3: map the data to a single table
    IF entity_c IS NOT INITIAL.
      entities = CORRESPONDING #( entity_c ).
      operation = if_abap_behv=>op-m-create.
    ELSE.
      entities = entity_u.
      operation = if_abap_behv=>op-m-update.
    ENDIF.

    "STep 4: Clear the data in case user modified fields other than agency and customer
    DELETE entities WHERE %control-AgencyId = if_abap_behv=>mk-off
                    AND %control-CustomerId = if_abap_behv=>mk-off.

    "STep 5: filter only the unique agencies and customers
    agencies = CORRESPONDING #( entities DISCARDING DUPLICATES MAPPING agency_id = AgencyId EXCEPT * ).
    customers = CORRESPONDING #(  entities DISCARDING DUPLICATES MAPPING customer_id = CustomerId EXCEPT * ).

    "Step 6: Call DB tables for master data to load valid customers and agencies
    SELECT FROM /dmo/agency FIELDS agency_id, country_code
           FOR ALL ENTRIES IN @agencies WHERE agency_id = @agencies-agency_id
           INTO TABLE @DATA(lt_agency_country).

    SELECT FROM /dmo/customer FIELDS customer_id, country_code
           FOR ALL ENTRIES IN @customers WHERE customer_id = @customers-customer_id
           INTO TABLE @DATA(lt_customer_country).

    "STep 7: Loop at all the incoming data for validation and compare the countries of customer and agency
    LOOP AT entities INTO DATA(entity).
      READ TABLE lt_agency_country WITH KEY agency_id = entity-AgencyId INTO DATA(ls_agency_val).
      CHECK sy-subrc EQ 0.
      READ TABLE lt_customer_country WITH KEY customer_id = entity-CustomerId INTO DATA(ls_customer_val).
      CHECK sy-subrc EQ 0.
      "if condition to check if they both belongs to same country, if not throw error
      IF ls_agency_val-country_code <> ls_customer_val-country_code.
        "step 8: inform the RAP framework that something is fishy
        APPEND VALUE #(
                        %cid = COND #( WHEN operation = if_abap_behv=>op-m-create
                                            THEN entity-%cid_ref
                                     )
                        %is_draft = entity-%is_draft
                        %fail-cause = if_abap_behv=>cause-conflict

                       ) TO failed.
        APPEND VALUE #( %cid = COND #( WHEN operation = if_abap_behv=>op-m-create
                                           THEN entity-%cid_ref
                                    )
                       %is_draft = entity-%is_draft
                       %msg = NEW /dmo/cm_flight_messages(
                               textid = VALUE #( msgid = 'SY' msgno = 499
                                                 attr1 = 'The country code for '
                                                 attr2 = |{ entity-agencyid } and |
                                                 attr3 = entity-customerid
                                                 attr4 = 'does not match' )
                                agency_id = entity-AgencyId
                                customer_id = entity-CustomerId
                                severity = if_abap_behv_message=>severity-error
                                )
                        %element-agencyid = if_abap_behv=>mk-on
                       ) TO reported.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD precheck_create.
    precheck_kiran_reuse(
      EXPORTING
*        entity_u =
        entity_c = entities
      IMPORTING
        reported = reported-travel
        failed   = failed-travel
    ).
  ENDMETHOD.

  METHOD precheck_update.
    precheck_kiran_reuse(
       EXPORTING
         entity_u = entities
*        entity_c =
       IMPORTING
         reported = reported-travel
         failed   = failed-travel
     ).
  ENDMETHOD.

  METHOD acceptTravel.
    "Enable and disable of accept and rejecttravel buttons functionality is written in
    "GET_INSTANCE_FEATURES method in the RESULT data population
    "Change the travel status to approved using EML
    MODIFY ENTITIES OF zrap_kk_travel
        ENTITY travel
        UPDATE FIELDS ( overallstatus )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky
                                       %is_draft = key-%is_draft
                                       OverallStatus = 'A' ) ).

    "Read the data of BO instance again
    READ ENTITIES OF zrap_kk_travel
       ENTITY travel
       ALL FIELDS
       WITH CORRESPONDING #( keys )
       RESULT DATA(lt_result).

    "Return the data out
    result = VALUE #( FOR travel IN lt_result ( %tky = travel-%tky %param = travel ) ).
  ENDMETHOD.

  METHOD rejectTravel.
   "Enable and disable of accept and rejecttravel buttons functionality is written in
    "GET_INSTANCE_FEATURES method in the RESULT data population
    "Change the travel status to approved using EML
    MODIFY ENTITIES OF zrap_kk_travel
        ENTITY travel
        UPDATE FIELDS ( overallstatus )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky
                                       %is_draft = key-%is_draft
                                       OverallStatus = 'X' ) ).

    "Read the data of BO instance again
    READ ENTITIES OF zrap_kk_travel
       ENTITY travel
       ALL FIELDS
       WITH CORRESPONDING #( keys )
       RESULT DATA(lt_result).

    "Return the data out
    result = VALUE #( FOR travel IN lt_result ( %tky = travel-%tky %param = travel ) ).

  ENDMETHOD.

ENDCLASS.
