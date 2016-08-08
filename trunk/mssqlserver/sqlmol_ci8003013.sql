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
drop table sqlmol_compound_bonds
drop table sqlmol_compound_elements
drop table sqlmol_compound
drop table sqlmol_bond_type
drop table sqlmol_element_type
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
		pcode   char(2) COLLATE Latin1_General_CS_AS,
		bond_type varchar(40) COLLATE Latin1_General_CS_AS NOT NULL,
		primary key(bondid)
	)

	insert into @bonds(nodeid, code, pnodeid, bond, bondid, pcode, bond_type)
	select nodeid, code, pnodeid, bond, bondid, '', ''
	from dbo.fn_sqlmol_smi2tbl(@smi) n 
	where isnull(bond, '') <> ''

	update @bonds 
	set bond_type= 
		case when b1.code<= b2.code 
		then b1.code+b1.bond+b2.code COLLATE Latin1_General_CS_AS 
		else b2.code+b1.bond+b1.code COLLATE Latin1_General_CS_AS end,
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
END
GO

-- the data set for testing is copied from openbabel project (http://openbabel.org)
-- file name: nci.smi
-- and imported into database as table nci
insert into sqlmol_compound(compoundid, smiles)
select cid, smiles from nci

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
		dir smallint, n2 smallint, n1 smallint, bid varchar(100)
	)

	;WITH bonds(nodeid, code, pnodeid, bond, bondid) as (
		select nodeid, code, pnodeid, bond, bondid 
		from dbo.fn_sqlmol_smi2tbl(@smi) 
		--where isnull(bond, '') <> ''
	)
	insert into @bondz
	select 
		case when b1.code<= b2.code 
			then b1.code+b1.bond+b2.code COLLATE Latin1_General_CS_AS 
			else b2.code+b1.bond+b1.code COLLATE Latin1_General_CS_AS end as bond_type,
		case when b1.code<= b2.code 
			then 1 else 2 end as dir,      -- up/ down, 1 if b1.nodeid is up
		b1.nodeid  as n2,
		b1.pnodeid as n1,
		b1.bondid  as bid
	from bonds b1 left join (select * from bonds) b2 on b1.pnodeid=b2.nodeid

    -- select * from @bondz
    
	declare @bond1 varchar(100)
	select top 1 @bond1=bid from @bondz where n1 >0
	set @sql= 'select distinct '+ @bond1+ '.compoundid from '
	select @sql= @sql+ ' sqlmol_compound_bonds '+ CAST(bid as varchar)+ ', ' from @bondz where n1>0
	select @sql= left(@sql, LEN(@sql)-1)
	select @sql= @sql+ ' where 1=1 '
	select @sql= @sql+ ' and ' + @bond1+ '.compoundid='+ bid+ '.compoundid' from @bondz where n1>0 and bid<> @bond1
	select @sql= @sql+ ' and ' COLLATE Latin1_General_CS_AS+ CAST(bid as varchar)+ '.btid='+ cast(t.btid as varchar)
	from @bondz b join sqlmol_bond_type t on b.bond_type=t.symbol


    --
    declare @bt char(6)
    declare c cursor for
        select bond_type from @bondz where bond_type is not null group by bond_type having count(*) >1
    open c
    fetch next from c into @bt
    while @@FETCH_STATUS=0
    BEGIN
        with same_type_bonds (bid) as ( select bid from @bondz where bond_type=@bt )
        select @sql = @sql+ (' and ' + sb1.bid + '.cbid<>' +sb2.bid+ '.cbid ') 
        from same_type_bonds sb1, same_type_bonds sb2 where sb1.bid< sb2.bid
        
        fetch next from c into @bt
    END
    close c
    deallocate c

    -- select * from @bondz
    
    --
    if exists( select bond_type from @bondz where patindex('%[~,*]%', bond_type)> 0 )
    BEGIN
        declare @bid varchar(1000) --, @bt char(6)
        declare @in varchar(1000) 
        declare c cursor for 
            select bid, bond_type from @bondz where patindex('%[~,*]%', bond_type)> 0
        open c
        fetch next from c into @bid, @bt
        while @@FETCH_STATUS=0
        BEGIN
            select @in= '' COLLATE Latin1_General_CS_AS
            select @in = @in + cast(btid as varchar)+ ', ' from sqlmol_bond_type 
                where symbol like REPLACE(REPLACE(@bt, '*', '%'), '~', '%')
            select @sql= @sql+ ' and ' COLLATE Latin1_General_CS_AS+ CAST(@bid as varchar)+ '.btid in('+ @in + '0)'
            fetch next from c into @bid, @bt
        END
        close c
        deallocate c
    END
    
	declare @atom_axis table( nid smallint, bondid varchar(100), dir smallint ) -- dir means the axis atom is up/down
	;WITH bonds(nodeid, code, pnodeid, bond, bondid) as (
		select nodeid, code, pnodeid, bond, bondid 
		from dbo.fn_sqlmol_smi2tbl(@smi) 
		--where isnull(bond, '') <> ''
	)
	insert into @atom_axis
	select n1, bid, case dir when 1 then 2 else 1 end from @bondz where n1>0
	union
	select n2, bid, dir  from @bondz where n1>0

	select @sql= @sql+ ' and ' COLLATE Latin1_General_CS_AS+ 
		a1.bondid+ '.ceid'+ CAST(a1.dir as varchar) +'='+ a2.bondid+ '.ceid' + CAST(a2.dir as varchar)
	from @atom_axis a1 join @atom_axis a2 on a1.nid=a2.nid and a1.bondid> a2.bondid

	select @sql= @sql+ ' and '+ max(a1.bondid + '.ceid'+ CAST(a1.dir as varchar) + '<>' + a2.bondid + '.ceid'+ CAST(a2.dir as varchar))
	from @atom_axis a1, @bondz b, @atom_axis a2
	where left(b.bond_type, 2)=RIGHT(b.bond_type, 2) and a1.nid=b.n1 and a2.nid=b.n2
	group by b.bid

	print @sql
	exec('select * from sqlmol_compound where compoundid in ('+@sql+')')
END
GO

-- Index
create index idx_sqlmol_compound_bonds_3 on sqlmol_compound_bonds(btid, compoundid, ceid1)
GO
create index idx_sqlmol_compound_bonds_4 on sqlmol_compound_bonds(btid, compoundid, ceid2)
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