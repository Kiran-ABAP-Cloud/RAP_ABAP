@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'Draft query view for ZRAP_KK_DTRAVEL'
define root view entity zrap_kk_travq
  as select from zrap_kk_dtravel
{
  key travelid as TravelId,
  agencyid as AgencyId,
  agencyname as AgencyName,
  customerid as CustomerId,
  customername as CustomerName,
  begindate as BeginDate,
  enddate as EndDate,
  bookingfee as BookingFee,
  totalprice as TotalPrice,
  currencycode as CurrencyCode,
  description as Description,
  overallstatus as OverallStatus,
  minion as Minion,
  statustext as StatusText,
  createdby as CreatedBy,
  createdat as CreatedAt,
  lastchangedby as LastChangedBy,
  lastchangedat as LastChangedAt,
  draftentitycreationdatetime as draftentitycreationdatetime,
  draftentitylastchangedatetime as draftentitylastchangedatetime,
  draftadministrativedatauuid as draftadministrativedatauuid,
  draftentityoperationcode as draftentityoperationcode,
  hasactiveentity as hasactiveentity,
  draftfieldchanges as draftfieldchanges
}
