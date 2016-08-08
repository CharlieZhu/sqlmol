-- v b

exec search_by_smi 'c1cncnc1'

select distinct b3_1.compoundid from  sqlmol_compound_bonds b3_1,  sqlmol_compound_bonds b4_3,  sqlmol_compound_bonds b5_4,  sqlmol_compound_bonds b6_5,  sqlmol_compound_bonds b7_1,  sqlmol_compound_bonds b7_6 
where 1=1  and b3_1.compoundid=b4_3.compoundid and b3_1.compoundid=b5_4.compoundid and b3_1.compoundid=b6_5.compoundid and b3_1.compoundid=b7_1.compoundid and b3_1.compoundid=b7_6.compoundid 
and b3_1.btid=5 and b7_1.btid=5 and b4_3.btid=6 and b5_4.btid=6 and b6_5.btid=6 and b7_6.btid=6 
and b4_3.cbid<> b5_4.cbid and b5_4.cbid<>b6_5.cbid and b6_5.cbid<> b4_3.cbid and b7_6.cbid<> b6_5.cbid and b7_6.cbid<> b5_4.cbid
and b7_1.ceid2=b3_1.ceid2 and b4_3.ceid1=b3_1.ceid1 and b5_4.ceid2=b4_3.ceid2 and b6_5.ceid1=b5_4.ceid1 and b7_6.ceid2=b6_5.ceid2 and b7_6.ceid1=b7_1.ceid1 
and b7_1.ceid2<>b4_3.ceid1 and b7_1.ceid2<>b7_6.ceid1

-- 81, Nc1ccc(Cl)nc1
select * from dbo.vw_compound where compoundid=81
select * from sqlmol_compound_bonds where compoundid=81
-- bond ÷ÿ∏¥
select * from dbo.fn_sqlmol_smi2tbl('Nc1ccc(Cl)nc1')
