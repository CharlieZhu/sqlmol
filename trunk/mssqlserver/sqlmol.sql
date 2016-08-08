/**********************************************************************
sqlmol.sql - Defination of function fn_sqlmol_smi2tbl that
             convert SMILES string to bond table.
 
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

/*
------
A Parse Unit (bond, atom)
CASES
 #   lead  symbol      comment
---+-----+----------+-------------
 1    0     A          start of string
 2    A     A          implicit bond
 3    A     B, A       typical
 4    A     R          branch
------
TODO
 - Dot seperator
 - Aromaticity bond recgonizing
 - Explicit bond type recgonized as aromaticity
 - Dead loop when symbol encountered not in symbol table
 */
drop function fn_sqlmol_smi2tbl
GO
create function fn_sqlmol_smi2tbl (
    @smi varchar(max)
)
returns @bonds table (
    nodeid  smallint not null,
    code    char(2) COLLATE Latin1_General_CS_AS,
    pnodeid smallint not null,
    bond    char(2) COLLATE Latin1_General_CS_AS,
    bondid as 'b'+ (cast(nodeid as varchar)+'_'+cast(pnodeid as varchar))
    primary key(nodeid, pnodeid)
)
as
BEGIN
	/*
	declare @smi as varchar(max)
	set @smi = 'c12c(c(=O)[nH]c(=O)[nH]2)[nH]c(=O)[nH]1'
	set @smi = 'N(=O)(=O)c*'
	declare @bonds table (
		nodeid  smallint not null,
		code    char(2) COLLATE Latin1_General_CS_AS,
		pnodeid smallint not null,
		bond    char(2),
		primary key(nodeid, pnodeid)
	)
	*/
	
	-- Replace unsupported bond types
	set @smi= replace(@smi, '@@', '-')
	set @smi= replace(@smi, '@',  '-')
	set @smi= replace(@smi, '/',  '-')
	set @smi= replace(@smi, '\',  '-')
	
	
	-- Dot seperator
	declare @i tinyint
	set @i= 1
	while charindex('.', @smi)> 0
	BEGIN
		declare @doti int
		set @doti= charindex('.', @smi)
		insert into @bonds
		select nodeid+@i*8000, code, pnodeid+@i*8000, bond
		from dbo.fn_sqlmol_smi2tbl(left(@smi, @doti-1))
		set @smi= right(@smi, len(@smi)- @doti)
		set @i= @i+ 1
	END
	declare @offset smallint
	set @offset = 1

	declare 
		@b   char(2),  -- bond
		@api smallint,
		@bi  smallint,
		@f   smallint,
		@code char(2), -- symbol code
		@tp  char(1),  -- symbol type
		@ar  bit,      -- symbol aromaticity
		@pcode char(2) -- previous symbol code

	declare @cyclic table (
		cycid   smallint primary key,
		nodeid1 smallint null,
		nodeid2 smallint null,
		bond    char(2) not null default '-'
	)

	declare @branch_stack table (
		id      int not null identity(1,1) primary key,
		api     smallint not null
	)

	while @offset <= LEN(@smi)
	BEGIN
		set @b= ''               -- default bond
		set @tp= NULL
	    
		select @code=code, @tp=[type], @ar=Aromaticity, @f=Offset 
		from dbo.fn_next_symbol(SUBSTRING(@smi, @offset, LEN(@smi)- @offset+1))
		-- if @tp is null  RAISERROR(N'Can not found next symbol', 12, 100)
		
		if @tp= 'b'              -- case 3
		BEGIN
			set @offset= @offset+ @f
			set @b= @code
			select @code=code, @tp=[type], @ar=Aromaticity, @f=Offset 
			from dbo.fn_next_symbol(SUBSTRING(@smi, @offset, LEN(@smi)- @offset+1))
			-- if @tp is null  RAISERROR(N'Can not found next symbol', 12, 100)
		END
	       
		if @tp in ('a')          -- case 1, 2, 3
		BEGIN
		    -- print @code
			if @offset = 1       -- case 1
			BEGIN
				set @api = 0
				set @b   = ''
			END
		    
		    if @b= '' and @ar= 1 -- Aromaticity bond recognization, both end of bond is aromaticity
		        and exists(
					select 1
					from @bonds b, sqlmol_symbol s
					where b.code=s.code and nodeid=@api and s.Aromaticity=1 )
				-- and --Nc1cc(-c2ccc([N+](=O)[O-])cc2)n[nH]1
		        set @b = ':' 
		    
		    if @b= '' and        -- SMARTS wild card supports
		       ( ( @ar= 1 or (select Aromaticity from @bonds b, sqlmol_symbol s where b.code=s.code and nodeid=@api )=1 ) and
		         ( @code= '*' or (select code from @bonds where nodeid=@api )='*' ) )
		        set @b = '~'

					
		    if @b= '' set @b='-'
		    
			insert @bonds select @offset, @code, @api, @b
			set @api    = @offset
			set @offset = @offset+ @f
		    
		END
		
		if @tp in ('l')          -- Cyclic, LOOP
		BEGIN
			-- print @code
			declare @cycid as smallint
			select @cycid= CAST(@code as smallint)
			if exists( select cycid from @cyclic where cycid=@cycid)
				update @cyclic 
				set 
				    nodeid2= @api,
				    bond= case 
				          when not @b='' then @b
				          when  -- Wild card for bond, any bond
				               exists( select b.nodeid from @bonds b join sqlmol_symbol s on b.code=s.code  
				                       and s.code='*' )
				               then '~'
				          when  -- Aromaticity bond recognization, both end of bond is aromaticity
							  ( select min(cast(Aromaticity as smallint) )  
								from @bonds b join sqlmol_symbol s on b.code=s.code 
								where b.nodeid in (@api, nodeid1))=1
				              then ':' 
				          else bond end
				where cycid=@cycid
			else
				insert into @cyclic values(@cycid, @api, NULL, '-')
			set @offset= @offset+ @f
		END
		
		if @tp in ('r')          -- Branch
		BEGIN
			if @code= '('
				insert @branch_stack select @api
			if @code= ')'
			BEGIN
				declare @id int
				select top 1 @api= api, @id=id from @branch_stack order by id desc
				delete @branch_stack where id=@id
			END
			set @offset= @offset+ @f
		END
		
		if @tp is null or @tp = ''   -- Unrecgonizable symbol
		    RETURN

	END

	insert @bonds(nodeid, code, pnodeid, bond)
	select 
		nodeid2,
		(select code from @bonds where nodeid=nodeid2),
		nodeid1,
		bond
	from @cyclic
    

    RETURN
END   
GO 
/*
	select * from @bonds

	BEGIN TRY

	END TRY
	BEGIN CATCH
		SELECT 
			ERROR_NUMBER() as ErrorNumber,
			ERROR_MESSAGE() as ErrorMessage;

	END CATCH
*/

    declare @smi varchar(max)
    set @smi = 'N(=O)(=O)*s'
		select nodeid, code, pnodeid, bond, bondid 
		from dbo.fn_sqlmol_smi2tbl(@smi) 
