/**********************************************************************
sqlmol_consts.sql - Constant lookup table for symbol used in SMILES. 
                    Including Periodic Table of Elements.
 
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
drop table sqlmol_symbol
GO
create table sqlmol_symbol (
    code char(2) COLLATE Latin1_General_CS_AS not null primary key,
    [type] char(1), 
    Aromaticity bit not null default 0
) 
GO
-- Atoms
insert into sqlmol_symbol values ('C', 'a', 0)
insert into sqlmol_symbol values ('c', 'a', 1)
insert into sqlmol_symbol values ('N', 'a', 0)
insert into sqlmol_symbol values ('n', 'a', 1)
insert into sqlmol_symbol values ('P', 'a', 0)
insert into sqlmol_symbol values ('p', 'a', 1)
insert into sqlmol_symbol values ('O', 'a', 0)
insert into sqlmol_symbol values ('o', 'a', 1)
insert into sqlmol_symbol values ('S', 'a', 0)
insert into sqlmol_symbol values ('s', 'a', 1)
insert into sqlmol_symbol values ('As', 'a', 0)
insert into sqlmol_symbol values ('as', 'a', 1)
insert into sqlmol_symbol values ('Se', 'a', 0)
insert into sqlmol_symbol values ('se', 'a', 1)
insert into sqlmol_symbol values ('Cl', 'a', 0)
insert into sqlmol_symbol values ('Br', 'a', 0)
insert into sqlmol_symbol values ('I', 'a', 0)

insert into sqlmol_symbol values ('B', 'a', 0)
insert into sqlmol_symbol values ('F', 'a', 0)
insert into sqlmol_symbol values ('Si', 'a', 0)

insert into sqlmol_symbol values ('*', 'a', 0) -- wild card in SMARTS

-- Bonds
insert into sqlmol_symbol values ('~', 'b', 0) -- wild card, any bond
insert into sqlmol_symbol values ('-', 'b', 0)
insert into sqlmol_symbol values ('=', 'b', 0)
insert into sqlmol_symbol values ('#', 'b', 0)
insert into sqlmol_symbol values (':', 'b', 1)

-- Branch
insert into sqlmol_symbol values ('(', 'r', 0)
insert into sqlmol_symbol values (')', 'r', 0)

-- Loop
-- 