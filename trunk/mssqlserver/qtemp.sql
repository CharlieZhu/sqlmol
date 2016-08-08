-- trunk --
/*
 * Stored procedure search_by_smi
 * Query compound id list by SMILES string
 * The SQL Query is built as dynamic SQL and executed
 *
 * 2009/02/10, Charlie Zhu, http://blog.charliezhu.com
 */
    declare @smi varchar(max)
    set @smi = 'c1cncnc1'
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
