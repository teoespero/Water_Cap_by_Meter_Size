--------------------------------------------------------------------------
-- Water Capacity by Meter Size
-- Written by: Teo Espero, IT Administrator
-- Date written: 12/19/2022
-- Description:
--		This code was written to provide the Water Resources Department 
--		the means to identify all the water meters that are deployed 
--		within the district.
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- STEP 1
-- Define the data set based on the last completed billing period. This
-- will provide the user with accounts that were read in that period.
-- Note that the count it provides does not directly reflect that of the 
-- actual connections/meters in the ground.
--------------------------------------------------------------------------
select 
	distinct
	reading_period,
	cust_no,
	cust_sequence
	into #meters_read
from ub_meter_hist
where
	reading_year = 2022
	and reading_period = 11
order by
	reading_period

-- view the resulting data set
select * from #meters_read



--------------------------------------------------------------------------
-- STEP 2
-- Using the data set provided by the previous step. Cross reference it
-- with the master accounts table to get the lot nos associated with the
-- account. The lot no is key in getting the meter information.
--------------------------------------------------------------------------
select 
	mr.cust_no,
	mr.cust_sequence,
	mast.lot_no,
	mast.connect_date,
	mast.final_date
	into #get_lots
from #meters_read mr
inner join
	ub_master mast
	on mast.cust_no=mr.cust_no
	and mast.cust_sequence=mr.cust_sequence

-- view the resulting data set
select * from #get_lots



--------------------------------------------------------------------------
-- STEP 3
-- Since once meter connection can actually have multiple accounts linked
-- to it, and one lot can have multiple meter devices linked to it
-- throughout its lifetime. We will get the latest record on the system 
-- for that lot number, this will provide us the latest meter information
-- in Springbrook.
--------------------------------------------------------------------------
select 
	t.cust_no,
	t.cust_sequence,
	t.lot_no,
	t.connect_date,
	t.final_date
	into #unique_lots
from #get_lots t
inner join (
	select lot_no, 
	max(connect_date) as MaxTrans
    from #get_lots
    group by lot_no
) tm 
on 
	t.lot_no = tm.lot_no
	and t.connect_date=tm.MaxTrans
order by
	t.lot_no,
	t.cust_no,
	t.cust_sequence

-- view the resulting data set
select * from #unique_lots



--------------------------------------------------------------------------
-- STEP 4
-- Exclude Bay View data, we will only be tracking meters that are directly
-- connected to the water mains. Submeters like the ones used in Bay View 
-- will be excluded. Only the main Bay View account is used.
-- Account is 000990-000 Bay View
--------------------------------------------------------------------------
select 
	ul.cust_no,
	ul.cust_sequence,
	ul.lot_no,
	l.misc_1,
	l.misc_2
	into #custnoseq
from #unique_lots ul
inner join
	lot	l
	on l.lot_no=ul.lot_no
	and l.misc_5 != 'Bay View'
union select 
	ul.cust_no,
	ul.cust_sequence,
	ul.lot_no,
	l.misc_1,
	l.misc_2
from #unique_lots ul
inner join
	lot	l
	on l.lot_no=ul.lot_no
	and l.misc_5 = 'Bay View'
	and ul.cust_no=990
	and ul.cust_sequence=0

-- view the resulting data
-- this data should be consistent with the latest
-- connections data provided to Conservation 
select * from #custnoseq



--------------------------------------------------------------------------
-- STEP 5
-- Cross reference the data with the meter consumption table
-- This will provide us the console id and device id we need to 
-- identify the meter type being used
--------------------------------------------------------------------------
select 
	cs.cust_no,
	cs.cust_sequence,
	con.ub_meter_con_id,
	con.ub_device_id,
	con.install_date,
	cs.lot_no,
	cs.misc_1,
	cs.misc_2
	into #uniqueconid
from #custnoseq cs
inner join
	ub_meter_con con
	on con.lot_no=cs.lot_no
order by
	cs.cust_no,
	cs.cust_sequence,
	con.ub_meter_con_id

-- view the data set
select * from #uniqueconid



--------------------------------------------------------------------------
-- STEP 6
-- Since the previous set will contain multiple console id
-- related to the account and lot, we will need to get the latest id
--------------------------------------------------------------------------
select 
	t.cust_no,
	t.cust_sequence,
	t.ub_meter_con_id,
	t.ub_device_id,
	t.install_date,
	t.lot_no,
	t.misc_1,
	t.misc_2
	into #get_conid
from #uniqueconid t
inner join (
	select lot_no, 
	max(ub_meter_con_id) as MaxTrans
    from #uniqueconid
    group by lot_no
) tm 
on 
	t.lot_no = tm.lot_no
	and t.ub_meter_con_id=tm.MaxTrans
order by
	t.cust_no,
	t.cust_sequence,
	t.lot_no

-- view the unique sets of console id
select * from #get_conid



--------------------------------------------------------------------------
-- STEP 7
-- Using the device type id in the set, we will cross reference it
-- with the devices table, this will provide us the meter info we need
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Revision history
-- Date modified: 12/20/2022
-- Modified by: TEspero
-- Description:
--		Case statements to determine the decimal equivalent for the meter
--		sizes were added, this is to automate the result.
--------------------------------------------------------------------------
-- A
-- get the decimal equivalent of the meter sizes

select 
	gc.misc_1 as Boundary,
	gc.misc_2 as STCategory,
	gc.cust_no,
	gc.cust_sequence,
	gc.ub_meter_con_id,
	gc.ub_device_id,
	gc.install_date,
	gc.lot_no,
	ud.serial_no,
	ud.ub_device_type_id,
	DT.manufacturer,
	dt.model_no,
	(
	case
		when dt.device_size = '5/8'		then 0.625
		when dt.device_size = '3/4'		then 0.75
		when dt.device_size = '1'		then 1
		when dt.device_size = '1 1/2'	then 1.5
		when dt.device_size = '2'		then 2
		when dt.device_size = '3'		then 3
		when dt.device_size = '4'		then 4
		when dt.device_size = '6'		then 6
		when dt.device_size = '8'		then 8
		when dt.device_size = '10'		then 10
		when dt.device_size = '12'		then 12
		else 0
	end
	) as device_size
	into #devsizeset
from #get_conid gc
inner join
	ub_device ud
	on ud.ub_device_id=gc.ub_device_id
inner join
	ub_device_type dt
	on dt.ub_device_type_id=ud.ub_device_type_id
order by
	gc.misc_1,
	gc.misc_2


--------------------------------------------------------------------------
-- Revision history
-- Date modified: 12/20/2022
-- Modified by: TEspero
-- Description:
--		Case statements to determine the meter cap ratio for the meter
--		sizes were added, this is to automate the result.
--------------------------------------------------------------------------
-- B
-- get the meter capacity ratio (3/4 equiv) for each meter size
select 
	Boundary,
	STCategory,
	cust_no,
	cust_sequence,
	ub_meter_con_id,
	ub_device_id,
	install_date,
	lot_no,
	serial_no,
	ub_device_type_id,
	manufacturer,
	model_no,
	device_size,
	(
	case
		when device_size = 0.625		then 1.00
		when device_size = 0.75			then 1.00
		when device_size = 1			then 1.67
		when device_size = 1.5			then 3.33
		when device_size = 2			then 5.33
		when device_size = 3			then 11.67
		when device_size = 4			then 21.00
		when device_size = 6			then 43.33
		when device_size = 8			then 93.33
		when device_size = 10			then 140.00
		when device_size = 12			then 176.67
		else 0
	end
	) as meter_cap_ratio
	into #metercapz
from #devsizeset dz
order by
	Boundary,
	STCategory


--------------------------------------------------------------------------
-- Revision history
-- Date modified: 12/20/2022
-- Modified by: TEspero
-- Description:
--		The water capacity AFY computation is included in the select 
--		statement. The resulting data set can be considered
--		Excel export ready.
--------------------------------------------------------------------------
-- C
-- compute for the water capacity in AFY units
select 
	Boundary,
	STCategory,
	cust_no,
	cust_sequence,
	ub_meter_con_id,
	ub_device_id,
	install_date,
	lot_no,
	serial_no,
	ub_device_type_id,
	manufacturer,
	model_no,
	device_size,
	meter_cap_ratio,
	((device_size * meter_cap_ratio)/0.28) as Capacity_AFY
from #metercapz



--------------------------------------------------------------------------
-- STEP 8
-- Release all temp tables used
--------------------------------------------------------------------------
drop table #custnoseq
drop table #uniqueconid
drop table #get_conid
drop table #get_lots
drop table #meters_read
drop table #unique_lots
drop table #devsizeset
drop table #metercapz

--------------------------------------------------------------------------