@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Root CDS Entity for travel request'
@Metadata.ignorePropagatedAnnotations: true
@VDM.viewType: #COMPOSITE
define root view entity ZRAP_KK_TRAVEL
  as select from /dmo/travel_m
  composition [0..*] of ZRAP_KK_BOOKING              as _Booking
  association of one to one /DMO/I_Agency            as _Agency        on $projection.AgencyId = _Agency.AgencyID
  association of one to one /DMO/I_Customer          as _Customer      on $projection.CustomerId = _Customer.CustomerID
  association of one to one I_Currency               as _Currency      on $projection.CurrencyCode = _Currency.Currency
  association of one to one /DMO/I_Overall_Status_VH as _OverallStatus on $projection.OverallStatus = _OverallStatus.OverallStatus
{
      @ObjectModel.text.element: [ 'Description' ]
  key travel_id                                                        as TravelId,
      //Objectmodel is to display the description for agency for user to understand
      //and this need to be projected in projection layer as UI is built on top of ZRAP_KK_TRAVEL_PROCESSOR projection
      @ObjectModel.text.element: [ 'AgencyName' ]
      agency_id                                                        as AgencyId,
      _Agency.Name                                                     as AgencyName,
      @ObjectModel.text.element: [ 'CustomerName' ]
      customer_id                                                      as CustomerId,
      concat( concat(_Customer.FirstName, ' '), _Customer.LastName)    as CustomerName,
      begin_date                                                       as BeginDate,
      end_date                                                         as EndDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      booking_fee                                                      as BookingFee,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_price                                                      as TotalPrice,
      currency_code                                                    as CurrencyCode,
      description                                                      as Description,
      @ObjectModel.text.element: [ 'StatusText' ]
      overall_status                                                   as OverallStatus,
//Below is to color code the status and this filed need to be exposed in projection ZRAP_KK_TRAVEL_PROCESSOR
//and add the ctiticality option in @UI.Lineitem in MDE against Status field      
      case overall_status
      when  'O' then 2
      when 'A' then 3
      when 'X' then 1
      else 1
      end                                                              as Minion,
      _OverallStatus._Text[ Language = $session.system_language ].Text as StatusText,
      @Semantics.user.createdBy: true
      created_by                                                       as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                                                       as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by                                                  as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      //Will be treated as eTAG
      last_changed_at                                                  as LastChangedAt,
      //Extra virtual column to show status in color
      _Agency,
      _Customer,
      _Currency,
      _OverallStatus,
      _Booking
}
