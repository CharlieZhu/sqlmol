<<<<<<< .mine
<<<<<<< .mine
--*BRanch*--
=======
--**--
=======
--*TRUNK*--
>>>>>>> .r58
>>>>>>> .r57
/*
-- select * from sqlmol_hfbond_type
select * from sqlmol_compound_hfbonds cb, sqlmol_hfbond_type t where compoundid=6 and cb.btid=t.btid order by ceid
-- 
select * 
from sqlmol_compound_hfbonds b1, sqlmol_compound_hfbonds b2, sqlmol_compound_hfbonds b3, sqlmol_compound_hfbonds b4
where
    b1.compoundid=b2.compoundid and b1.compoundid=b3.compoundid and b1.compoundid=b4.compoundid
    and b1.btid=3 and b2.btid=2 and b3.btid= 1 and b4.btid=11   -- C=O-O
    and b1.cbid=b2.cbid and b3.cbid=b4.cbid
    and b2.ceid=b3.ceid

select distinct b4_1.compoundid from  sqlmol_compound_bonds b4_1,  sqlmol_compound_bonds b8_1,  sqlmol_compound_bonds b10_1,  sqlmol_compound_bonds b11_10 
where 1=1  
and b4_1.compoundid=b8_1.compoundid and b4_1.compoundid=b10_1.compoundid and b4_1.compoundid=b11_10.compoundid 
and b11_10.btid=7 and b10_1.btid=10 and b4_1.btid=13 and b8_1.btid=13 
and b4_1.cbid<>b8_1.cbid  
and b4_1.ceid1=b10_1.ceid2 and b8_1.ceid1=b10_1.ceid2 and b8_1.ceid1=b4_1.ceid1 and b11_10.ceid1=b10_1.ceid1
*/

/*
 * Stored procedure search_by_smi
 * Query compound id list by SMILES string
 * The SQL Query is built as dynamic SQL and executed
 *
 * 2009/02/10, Charlie Zhu, http://blog.charliezhu.com
 */
    declare @smi varchar(max)
    set @smi = 'C(=O)(c1ccc(C)cc1)c1ccc(Cl)cc1'
	declare @sql varchar(max)
	select @sql = ''

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
	*/
	select * from @bondz order by n2
    select * from @hbz
    select * from @atomz
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
    -- select @sql 
    print @sql
    exec(@sql)
    
/*
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

    select * from @bondz
    
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

	select @sql
	-- exec(@sql)
*/
/*
*/
