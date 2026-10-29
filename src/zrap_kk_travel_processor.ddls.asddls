@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection layer for root travel entity'
@Metadata.ignorePropagatedAnnotations: false
@VDM.viewType: #CONSUMPTION
@Metadata.allowExtensions: true
define root view entity ZRAP_KK_TRAVEL_PROCESSOR as projection on ZRAP_KK_TRAVEL
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
    @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_RAP_KK_VE'
    @EndUserText.label: 'CO2 Tax'
    virtual CO2Tax: abap.int4,
    @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_RAP_KK_VE'
     @EndUserText.label: 'Day of Travel'
    virtual dayOfFlight: abap.char(10),
    /* Associations */
    _Agency,
    _Booking : redirected to composition child ZRAP_KK_BOOKING_PROCESSOR,
    _Currency,
    _Customer,
    _OverallStatus
}
