@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Root CDS Entity for travel request'
@Metadata.ignorePropagatedAnnotations: true
@VDM.viewType: #COMPOSITE
define root view entity ZRAP_KK_TRAVEL
  as select from /dmo/travel_m
  composition[0..*] of ZRAP_KK_BOOKING as _Booking
  association of one to one /DMO/I_Agency            as _Agency        on $projection.AgencyId = _Agency.AgencyID
  association of one to one /DMO/I_Customer          as _Customer      on $projection.CustomerId = _Customer.CustomerID
  association of one to one I_Currency               as _Currency      on $projection.CurrencyCode = _Currency.Currency
  association of one to one /DMO/I_Overall_Status_VH as _OverallStatus on $projection.OverallStatus = _OverallStatus.OverallStatus
{
  key travel_id       as TravelId,
      agency_id       as AgencyId,
      customer_id     as CustomerId,
      begin_date      as BeginDate,
      end_date        as EndDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      booking_fee     as BookingFee,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_price     as TotalPrice,
      currency_code   as CurrencyCode,
      description     as Description,
      overall_status  as OverallStatus,
      @Semantics.user.createdBy: true
      created_by      as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at      as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      //Will be treated as eTAG
      last_changed_at as LastChangedAt,
      _Agency,
      _Customer,
      _Currency,
      _OverallStatus,
      _Booking
}
