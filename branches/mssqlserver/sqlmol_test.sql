/**********************************************************************
sqlmol_consts.sql - Test
 
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
declare @sqlmol table (smi varchar(max))
insert into @sqlmol values( '' )
*/
declare @smi varchar(max)
select top 1 @smi= smiles from nci where smiles is not null order by newid()
print @smi
select @smi
select * from dbo.fn_sqlmol_smi2tbl(@smi)

-- select * from dbo.fn_sqlmol_smi2tbl('[Si](OCC(C(C(C(C(C(F)F)(F)F)(F)F)(F)F)(F)F)(F)F)(OCC(C(C(C(C(C(F)F)(F)F)(F)F)(F)F)(F)F)(F)F)(OC(C)(C)C)OC(C)(C)C')


/* ?
c1ccc(B2OC(C)(C)C(C)(C)O2)nc1
CCOC(=O)c1cnc(SC)nc1C(F)(F)F
COC(=O)c1ncoc1-c1ccccc1
*/