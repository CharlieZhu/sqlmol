/**********************************************************************
sqlmol_ci8003013.sql - Implementation of the following paper with
                       functions of SQLMOL

	Chemical Substructure Search in SQL
	Adel Golovin and Kim Henrick*
	EMBL-EBI Hinston Hall Genome Campus, Cambridge, U.K.
	J. Chem. Inf. Model., 2009, 49 (1), pp 22–27
	DOI: 10.1021/ci8003013
	Publication Date (Web): December 15, 2008
	Copyright © 2008 American Chemical Society
	* Corresponding author phone: +44 (0) 1223 494629; 
	fax: +44(0) 1223 494468; e-mail: henrick@ebi.ac.uk.
 
Copyright (C) 2009 by Charlie Zhu (charlie@charliezhu.com)
 
This file is part of the SQLMOL project.
For more information, see <http://code.google.com/p/sqlmol>
 
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation version 3 of the License.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
***********************************************************************/


/*-------------------------------*/
/*****  PART 1 Schema        *****/
/*-------------------------------*/

/*
 * Stored procedure compound2db
 * Parse compounds data from SMILES table into atom and bonds table
 *
 * 2009/02/10, Charlie Zhu, http://blog.charliezhu.com
 */

-- clean up
drop table sqlmol_compound_hfbonds
drop table sqlmol_compound_bonds
drop table sqlmol_compound_elements
drop table sqlmol_compound
drop table sqlmol_bond_type
drop table sqlmol_element_type
drop table sqlmol_hfbond_type
GO

-- user defined tables
create table sqlmol_element_type (
    symbol char(2) COLLATE Latin1_General_CS_AS primary key
    )
GO

create table sqlmol_bond_type (
    btid int identity(1,1) primary key, 
    symbol char(6) COLLATE Latin1_General_CS_AS,
    CONSTRAINT chk_sqlmol_bond_type_dir CHECK(left(symbol, 2)<= right(symbol, 2))
    )
GO

create table sqlmol_hfbond_type (
    btid int identity(1,1) primary key, 
    symbol char(4) COLLATE Latin1_General_CS_AS
    )
GO

create table sqlmol_compound(
    compoundid int primary key, 
    smiles varchar(max) 
    )

create table sqlmol_compound_elements(
    ceid bigint identity(1,1) primary key, 
    compoundid int references sqlmol_compound(compoundid), 
    atom char(2) COLLATE Latin1_General_CS_AS references sqlmol_element_type(symbol),
    nodeid int  -- a temp column to record nodeid in the compound SMILES been parsed
    )
GO

create table sqlmol_compound_bonds(
    cbid bigint identity(1,1) primary key, 
    compoundid int references sqlmol_compound(compoundid), 
    btid int references sqlmol_bond_type(btid),
    ceid1 bigint references sqlmol_compound_elements(ceid),
    ceid2 bigint references sqlmol_compound_elements(ceid)
    --, CONSTRAINT chk_sqlmol_compound_bonds_dir CHECK(ceid1< ceid2)    
    )
GO

create table sqlmol_compound_hfbonds(
    compoundid int references sqlmol_compound(compoundid), 
    chbid bigint identity(1,1) primary key, 
    ceid bigint references sqlmol_compound_elements(ceid),
    cbid bigint references sqlmol_compound_bonds(cbid),
    btid int references sqlmol_hfbond_type(btid),
    parserid varchar(50)
)
GO

/*-------------------------------*/
/*****  PART 2 Data          *****/
/*-------------------------------*/

/*
 * Stored procedure compound2db
 * Parse compounds data from SMILES table into atom and bonds table
 *
 * 2009/02/10, Charlie Zhu, http://blog.charliezhu.com
 */

drop procedure compound2db
GO
create procedure compound2db (
    @cid int,
    @smi varchar(max)
) as
BEGIN
	declare @bonds table(
		nodeid  smallint not null,
		code    char(2) COLLATE Latin1_General_CS_AS,
		pnodeid smallint not null,
		bond    char(2) COLLATE Latin1_General_CS_AS,
		bondid  varchar(100),
		pcode     char(2) COLLATE Latin1_General_CS_AS,
		bond_type char(6) COLLATE Latin1_General_CS_AS  NULL,
		hbtype1   char(4) COLLATE Latin1_General_CS_AS  NULL,
		hbtype2   char(4) COLLATE Latin1_General_CS_AS  NULL,
		primary key(bondid)
	)

	insert into @bonds(nodeid, code, pnodeid, bond, bondid, pcode, bond_type)
	select nodeid, code, pnodeid, bond, bondid, '', NULL
	from dbo.fn_sqlmol_smi2tbl(@smi) n 
	where isnull(bond, '') <> ''

	update @bonds 
	set bond_type= 
		    case when b1.code<= b2.code 
		        then b1.code+b1.bond+b2.code COLLATE Latin1_General_CS_AS 
		        else b2.code+b1.bond+b1.code COLLATE Latin1_General_CS_AS end,
		hbtype1 = b1.code+b1.bond COLLATE Latin1_General_CS_AS,
		hbtype2 = b2.code+b1.bond COLLATE Latin1_General_CS_AS,
		pcode= b2.code
	from @bonds b1 join (select * from @bonds) b2 on b1.pnodeid=b2.nodeid

	-- element types
	insert into sqlmol_element_type(symbol)
	select distinct code from @bonds where code not in (select symbol from sqlmol_element_type)

	-- compound elements
	insert into sqlmol_compound_elements(compoundid, atom, nodeid)
	select distinct @cid, code, nodeid from @bonds

	-- bond types
	insert into sqlmol_bond_type(symbol)
	select distinct bond_type from @bonds bt 
	where 
		(not exists( select btid from sqlmol_bond_type where symbol=bt.bond_type ))
		and isnull(bt.bond_type, '' )<> ''
		
	-- compound bonds
	insert into sqlmol_compound_bonds(compoundid, btid, ceid1, ceid2)
	select
		@cid,
		(select btid from sqlmol_bond_type where symbol= b.bond_type),
		case when e1.atom<= e2.atom then e1.ceid else e2.ceid end,
		case when e1.atom<= e2.atom then e2.ceid else e1.ceid end
	from 
		@bonds b ,
		sqlmol_compound_elements e1,
		sqlmol_compound_elements e2
	where
		e1.compoundid=@cid and e2.compoundid=@cid
		and b.nodeid=e1.nodeid
		and b.pnodeid=e2.nodeid

    -- half bond types
	insert into sqlmol_hfbond_type (symbol)
	select distinct hbtype1 from @bonds where hbtype1 not in (select symbol from sqlmol_hfbond_type) and hbtype1 is not null
	insert into sqlmol_hfbond_type (symbol)
	select distinct hbtype2 from @bonds where hbtype2 not in (select symbol from sqlmol_hfbond_type) and hbtype2 is not null

    -- compound half bonds
	insert into sqlmol_compound_hfbonds( compoundid, btid, cbid, ceid )
	select @cid , hbt.btid, b1.cbid, e.ceid
	from 
		sqlmol_compound_bonds b1, 
		sqlmol_bond_type bt,
		sqlmol_compound_elements e,
		sqlmol_hfbond_type hbt
	where 
		b1.ceid1=e.ceid 
		and b1.btid=bt.btid
		and hbt.symbol=e.atom+ SUBSTRING(bt.symbol, 3, 2)
		and b1.compoundid=@cid
	union 
	select @cid , hbt.btid, b1.cbid, e.ceid
	from 
		sqlmol_compound_bonds b1, 
		sqlmol_bond_type bt,
		sqlmol_compound_elements e,
		sqlmol_hfbond_type hbt
	where 
		b1.ceid2=e.ceid 
		and b1.btid=bt.btid
		and hbt.symbol=e.atom+ SUBSTRING(bt.symbol, 3, 2)
		and b1.compoundid=@cid
	

END
GO


    
-- the data set for testing is copied from openbabel project (http://openbabel.org)
-- file name: nci.smi
-- and imported into database as table nci
insert into sqlmol_compound(compoundid, smiles)
select top 100 percent cid, smiles from nci

-- fetch compound data into atoms and bonds table with procedure compound2db
declare @smi varchar(max)
declare @cid int
declare c cursor for 
    select compoundid, smiles from sqlmol_compound
open c
fetch next from c into @cid, @smi
while @@FETCH_STATUS=0
BEGIN
    print @smi
    exec compound2db @cid, @smi 
    fetch next from c into @cid, @smi
END
close c
deallocate c
GO

/*-------------------------------*/
/*****  PART 3 Query builder *****/
/*-------------------------------*/

drop procedure search_by_smi
GO
/*
 * Stored procedure search_by_smi
 * Query compound id list by SMILES string
 * The SQL Query is built as dynamic SQL and executed
 *
 * 2009/02/10, Charlie Zhu, http://blog.charliezhu.com
 */
create procedure search_by_smi (
    @smi varchar(max)
)
as
BEGIN
	declare @sql varchar(max)

	declare @bondz table( 
		bond_type char(6) COLLATE Latin1_General_CS_AS, 
		n2 smallint, n1 smallint, 
		bid varchar(100) not null primary key, 
		hb1id varchar(100), hb2id varchar(100), 
		hb1 char(4) COLLATE Latin1_General_CS_AS,
		hb2 char(4) COLLATE Latin1_General_CS_AS
	)
	
	declare @atomz table(  -- atoms that joined by bonds
	    nid varchar(10) not null, hb1id varchar(100), hb2id varchar(100)
	)
	
	declare @hbz table(
	    hbid varchar(100) not null primary key,
	    hb char(4) COLLATE Latin1_General_CS_AS,
	    nid varchar(10),
	    bid varchar(100),
	    bond_type char(6) COLLATE Latin1_General_CS_AS
	)

    -- bonds
	;WITH bonds(nodeid, code, pnodeid, bond, bondid) as (
		select nodeid, code, pnodeid, bond, bondid 
		from dbo.fn_sqlmol_smi2tbl(@smi) 
		--where isnull(bond, '') <> ''
	)
	insert into @bondz
	select distinct 
		case when b1.code<= b2.code 
			then b1.code+b1.bond+b2.code COLLATE Latin1_General_CS_AS 
			else b2.code+b1.bond+b1.code COLLATE Latin1_General_CS_AS end as bond_type,
		b1.nodeid  as n2,
		b1.pnodeid as n1,
		b1.bondid  as bid,
		b1.bondid+ '_1' as hb1id,
		b1.bondid+ '_2' as hb2id,
		b1.code + b1.bond COLLATE Latin1_General_CS_AS as hb1,
		b2.code + b1.bond COLLATE Latin1_General_CS_AS as hb2
	from bonds b1 left join (select * from bonds) b2 on b1.pnodeid=b2.nodeid

	-- half bonds
    insert into @hbz
    select hb1id as hbid, hb1 as hb, n2 as n, bid, bond_type from @bondz where bond_type is not null
    union
    select hb2id,         hb2,       n1,      bid, bond_type from @bondz where bond_type is not null

    -- atoms
    insert into @atomz
    select h1.nid, h1.hbid, h2.hbid from @hbz h1, @hbz h2 where h1.nid=h2.nid and h1.hbid> h2.hbid

	/*
    select * from @hbz
    select * from @atomz
	*/
    -- build the dynamic query
    declare @basehb varchar(100)
    select @basehb  = MIN(hbid) from @hbz
        
	set @sql= 'select distinct '+ @basehb+ '.compoundid from '
    select @sql= @sql+ char(13)+char(10)+ ' sqlmol_compound_hfbonds '+ hbid+ ', ' from @hbz
	select @sql= left(@sql, LEN(@sql)-1)
 	select @sql= @sql+ char(13)+char(10)+ ' where 1=1 '
    select @sql= @sql+ char(13)+char(10)+ ' and '+ @basehb+ '.compoundid= '+ hbid+'.compoundid' from @hbz where hbid<> @basehb
    select @sql= @sql+ char(13)+char(10)+ ' and '+ hbid+ '.btid='+ CAST(t.btid as varchar) from @hbz, sqlmol_hfbond_type t where hb=t.symbol
    --
    declare @bt char(4)
    declare c cursor for
        select hb from @hbz where hb is not null group by hb having count(*) >1
    open c
    fetch next from c into @bt
    while @@FETCH_STATUS=0
    BEGIN
        with same_type_bonds (hbid) as ( select hbid from @hbz where hb=@bt )
        select @sql = @sql+ char(13)+char(10)+ (' and ' + sb1.hbid + '.chbid<>' +sb2.hbid+ '.chbid ') 
        from same_type_bonds sb1, same_type_bonds sb2 where sb1.hbid< sb2.hbid
        
        fetch next from c into @bt
    END
    close c
    deallocate c
    --
    if exists( select hb from @hbz where patindex('%[~,*]%', hb)> 0 )
    BEGIN
        declare @hbid varchar(100) --, @bt char(4)
        declare @in varchar(1000) 
        declare c cursor for 
            select hbid, hb from @hbz where patindex('%[~,*]%', hb)> 0
        open c
        fetch next from c into @hbid, @bt
        while @@FETCH_STATUS=0
        BEGIN
            select @in= '' COLLATE Latin1_General_CS_AS
            select @in = @in + cast(btid as varchar)+ ', ' from sqlmol_hfbond_type 
                where symbol like REPLACE(REPLACE(@bt, '* ', '_ '), '~ ', '_ ')
            select @sql= @sql+ char(13)+char(10)+ ' and ' COLLATE Latin1_General_CS_AS+ CAST(@hbid as varchar)+ '.btid in('+ @in + '0)'
            fetch next from c into @hbid, @bt
        END
        close c
        deallocate c
    END
    select @sql= @sql+ char(13)+char(10)+ ' and '+ hb1id+ '.cbid='+ hb2id+ '.cbid' from @bondz where bond_type is not null
    select @sql= @sql+ char(13)+char(10)+ ' and '+ hb1id+ '.ceid='+ hb2id+ '.ceid' from @atomz 

	print @sql
	exec('select * from sqlmol_compound where compoundid in ('+@sql+')')
END
GO

-- Index
create index idx_sqlmol_compound_bonds_3 on sqlmol_compound_bonds(btid, compoundid, ceid1)
GO
create index idx_sqlmol_compound_bonds_4 on sqlmol_compound_bonds(btid, compoundid, ceid2)
GO
create index idx_sqlmol_compound_hzbonds on sqlmol_compound_hfbonds(btid, compoundid, ceid, cbid)
GO

/*-------------------------------*/
/*****  PART 4 Test          *****/
/*-------------------------------*/

exec search_by_smi 'N(=O)(=O)cs'
/*
 The follow compoundid list should be returned
--------------
| compoundid |
+------------+
|          4 |
|        725 |
--------------
*/