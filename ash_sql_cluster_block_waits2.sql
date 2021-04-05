--
-- ASH script for SQLs and objects grouping from cluster waits concurrency for the same db blocks
-- May be useful for the Cluster waits problem periods
-- Usage: SQL> @ash_sql_cluster_block_waits2 SYSTEM.Ash_201912191425 "19.12.2019 12:40" "19.12.2019 12:42" "'6thhr9117y4ph','gpg0x4q06dhfd','c2gu4vz5xnudt','7255b9rm8890u'" 2 100
-- by Igor Usoltsev
--

set echo off feedback off heading on timi off pages 1000 lines 500 VERIFY OFF

col INST_ID1     for 9999999
col INST_ID2     for 9999999
col EVENT1       for a40
col EVENT2       for a40
col CLIENT_ID    for a40
col SQL_OPNAME1  for a12
col SQL_OPNAME2  for a12
col object_type  for a20
col object_name  for a40
col sql_text     for a100
col top_sql_text for a100

with ash as (select /*+ MATERIALIZE*/ * from &1--SYSTEM.Ash_201912191425
             where sample_time between nvl(to_date('&2','dd.mm.yyyy hh24:mi'),sysdate-1e6) and nvl(to_date('&3','dd.mm.yyyy hh24:mi'),sysdate+1e6)
             )
select--+ parallel(4)
       ash1.inst_id          as INST_ID1,
--       REGEXP_SUBSTR(ash1.client_id, '.+\#') as CLIENT_ID,
       ash1.sql_opname       as SQL_OPNAME1,
       ash1.sql_id           as SQL_ID1,
       ash1.event            as EVENT1,
----       ash1.blocking_inst_id as ASH_BLOCK_INST,    -- ����������� INST_ID �� ������ ASH
       ash2.inst_id          as REM_BLOCK_INST,    -- ����������� INST_ID �� ����������� �� ����� ��
--       REGEXP_SUBSTR(ash2.client_id, '.+\#') as BLK_CLIENT_ID,
       ash2.top_level_call_name       as CALL_NAME2,
       ash2.sql_opname       as SQL_OPNAME2,
----       nvl(ash2.sql_id, '  '||ash2.top_level_sql_id)
ash2.sql_id           as SQL_ID2, ash2.top_level_sql_id           as TOP_SQL_ID2,
       nvl(ash2.event, ash2.session_state)            as EVENT2,
       o.object_type,
       o.object_name,
       count(*)                                                as WAITS_COUNT,
       count(distinct ash1.current_file#||' '||ash1.current_block#) as CONC_BLOCK_COUNT,
       min(ash1.sample_time) as min_sample_time,
       max(ash1.sample_time) as max_sample_time
      ,dbms_lob.substr(ht.sql_text,100) as sql_text
--      ,dbms_lob.substr(ht2.sql_text,100) as top_sql_text
,ash1.current_file# 
,ash1.current_block#
from ash ash1
join ash ash2 on ash1.current_file#  = ash2.current_file#
             and ash1.current_block# = ash2.current_block#
--             and ash1.wait_class     = ash2.wait_class
--             and ash1.session_state  = ash2.session_state
             and ash1.p1text         = ash2.p1text
             and ash1.inst_id       <> ash2.inst_id                              -- � ������ ���
             and ash2.sample_time   <> ash1.sample_time                          -- ���������������
             and (ash1.sql_id in (&4))--(nvl('&4',ash1.sql_id)) or ash2.sql_id in (nvl('&4',ash2.sql_id)))
             and ABS(to_char(ash2.sample_time,'SSSSS') - to_char(ash1.sample_time,'SSSSS')) <= nvl('&5', 2) -- ����� �������������
left join dba_objects o on ash1.current_obj# = object_id
left join dba_hist_sqltext ht  on ash2.sql_id           = ht.sql_id
left join dba_hist_sqltext ht2 on ash2.top_level_sql_id = ht2.sql_id
where ash1.wait_class    = 'Cluster'                                             -- ����������
  and ash1.p1text        = 'file#'                                               -- ����-���������������
  and ash1.session_state = 'WAITING'                                             -- ��������
--  and ash1.event = nvl('&7', ash1.event)
group by ash1.inst_id,
         ash1.sql_opname,
         ash1.sql_id,
         ash1.event,
----         ash1.blocking_inst_id,
         ash2.inst_id,
         ash2.top_level_call_name,
         ash2.sql_opname,
----         nvl(ash2.sql_id, '  '||ash2.top_level_sql_id),
ash2.sql_id, ash2.top_level_sql_id,
         nvl(ash2.event, ash2.session_state),
--         REGEXP_SUBSTR(ash2.client_id, '.+\#'),
         o.object_type,
         o.object_name
--,        REGEXP_SUBSTR(ash1.client_id, '.+\#')
        ,dbms_lob.substr(ht.sql_text,100)
--        ,dbms_lob.substr(ht2.sql_text,100)
,ash1.current_file# 
,ash1.current_block#
having count(*) > nvl('&6', 0)
order by count(*) desc
/
set feedback on echo off VERIFY ON
