@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection layer for root travel entity'
@Metadata.ignorePropagatedAnnotations: false
@VDM.viewType: #CONSUMPTION
@Metadata.allowExtensions: true
define root view entity ZRAP_KK_TRAVEL_APPROVER as projection on ZRAP_KK_TRAVEL
{
    key TravelId,
    AgencyId,
    CustomerId,
    BeginDate,
    EndDate,
    BookingFee,
    TotalPrice,
    CurrencyCode,
    Description,
    OverallStatus,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    AgencyName,
    CustomerName,
    StatusText,       
    Minion,  
    /* Associations */
    _Agency,
    _Booking : redirected to composition child ZRAP_KK_BOOKING_APPROVER,
    _Currency,
    _Customer,
    _OverallStatus
}
