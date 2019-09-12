--
-- Current Lock Waits chains based on GV$LOCK
-- Usage: SQL> @lock_tree_local
-- Igor Usoltsev
--

set echo off feedback off heading on timi off pages 1000 lines 1000 VERIFY OFF

col BLOCKING_TREE for a30
col SQL_TEXT      for a100
col EVENT         for a40 head "Event name"
col USER_CLIENT   for a60
col P1TEXT        for a40
col P2TEXT        for a40
col P3TEXT        for a40
col BLOCK_SESSTAT for a13
col LAST_CALL_ET  for 999999999999
col SECS_IN_WAIT  for 999999999999
col MACHINE       for a36
col CLNT_PID      for a10
col OSUSER        for a10
col SPID          for a10
col REQ_OBJECT    for a61
col KILL_SESSION  for a50

/*
col SDATE for a21 NOPRI
col CHAR_DATE new_value SYS_DATE

, lockhold.con_id as BLOCKING_CON_ID
, lockhold.inst_id as BLOCKING_INSTANCE
, lockhold.sid as BLOCKING_SESSION
...
and gvs.LOCKWAIT = lockwait.KADDR(+)
and lockwait.id1 = lockhold.id1(+)
and lockwait.id2 = lockhold.id2(+)
and nvl(lockwait.REQUEST,1) > 0
and	nvl(lockwait.LMODE,0) = 0
and nvl(lockhold.REQUEST,0) = 0
and	nvl(lockhold.LMODE,1) > 0
and nvl(lockwait.SID,0) <> nvl(lockhold.SID,1)
*/
select to_char(sysdate,'dd.mm.yyyy hh24:mi:ss') CHAR_DATE from dual
/
/*
alter session set "_with_subquery"=optimizer
*/
with
 LOCKS    as (select /*+ MATERIALIZE*/   * from gv$lock where (block > 0 or REQUEST > 0) and type not in ('MR','AE')
 )
,S        as (select /*+ MATERIALIZE*/ s.* from gv$session s)
,BLOCKERS as
         (select distinct L1.inst_id, L1.sid, L1.con_id--, UTL_RAW.CAST_TO_VARCHAR2(L1.KADDR)
            from LOCKS L1, LOCKS L2
           where L1.block > 0
             and L1.ID1 = L2.ID1
             and L1.ID2 = L2.ID2
             and L2.REQUEST > 0)
,WAITERS  as (select inst_id, sid, con_id from S where blocking_session is not null or blocking_instance is not null
              union
              select distinct L2.inst_id, L2.sid, L2.con_id--, UTL_RAW.CAST_TO_VARCHAR2(L2.KADDR)
               from LOCKS L1, LOCKS L2
              where L1.block > 0
                and L1.ID1 = L2.ID1
                and L1.ID2 = L2.ID2
                and L2.REQUEST > 0)
--select inst_id, sid, con_id from BLOCKERS minus select inst_id, sid, con_id from WAITERS
--select s.* from s join WAITERS l on s.inst_id = l.inst_id and s.sid = l.sid
select-- opt_param('_connect_by_use_union_all' 'false')
--'&&SYS_DATE' as SDATE,
 LPAD(' ', (LEVEL - 1) * 2) || 'INST#' || s.inst_id || ' SID#' || s.sid || ' CON#' || s.con_id as BLOCKING_TREE,
l.type,
s.LOCKWAIT,
l.KADDR,
 s.program,
 substr(s.USERNAME || ' ' || s.CLIENT_IDENTIFIER,1,60) as USER_CLIENT,
 EVENT,
 object_type || ' ' || owner ||'.'|| object_name req_object,
 last_call_et,
 seconds_in_wait as SECS_IN_WAIT,
 blocking_session_status as BLOCK_SESSTAT,
 pdml_enabled,
 NVL(s.sql_id,s.prev_sql_id) as SQL_ID,
 s.osuser,
 p.spid,
 s.machine,
 s.process as CLNT_PID,
 s.port    as CLNT_PORT,
 substr(trim(NVL((select sa1.sql_text from gv$sqlarea sa1 where s.sql_id      = sa1.sql_id and rownum < 2),
                 (select sa2.sql_text from gv$sqlarea sa2 where s.prev_sql_id = sa2.sql_id and rownum < 2))), 1, 100) SQL_TEXT,
 decode(sign(nvl(s.ROW_WAIT_OBJ#, -1)), -1, 'NONE', DBMS_ROWID.ROWID_CREATE(1, s.ROW_WAIT_OBJ#, s.ROW_WAIT_FILE#, s.ROW_WAIT_BLOCK#, s.ROW_WAIT_ROW#)) as req_rowid,
 p1text || ' ' || decode(p1text, 'name|mode', chr(bitand(p1,-16777216)/16777215)||chr(bitand(p1, 16711680)/65535)||' '||bitand(p1, 65535), p1text)     as p1text,
 p1,
 p1raw,
 p2text || ' ' || decode(p2text, 'object #', o.object_name || ' ' || o.owner || '.' || o.object_name, '') as p2text,
 p2
/*,
 p2raw,
 p3text,
 p3,
 p3raw
*/
, 'Alter system kill session '''||s.SID||','||s.SERIAL#||','||'@'||s.INST_ID||''';' as KILL_SESSION
  from s
  left join LOCKS l on s.inst_id = l.inst_id and s.sid = l.sid and s.LOCKWAIT = l.KADDR--UTL_RAW.CAST_TO_RAW(s.LOCKWAIT) = l.KADDR
--  left join gv$sqlarea sa1 on s.sql_id = sa1.sql_id and s.inst_id =  sa1.inst_id and s.con_id =  sa1.con_id
--  left join gv$sqlarea sa2 on s.prev_sql_id = sa2.sql_id and s.inst_id =  sa2.inst_id and s.con_id =  sa2.con_id
  left join cdb_objects o  on s.p2 = o.object_id and s.con_id =  o.con_id -- here be dragonz
  left join gv$process p on s.paddr = p.addr and s.inst_id = p.inst_id and s.con_id = p.con_id
connect by NOCYCLE prior s.sid = nvl(blocking_session, l.sid) and prior s.inst_id = nvl(blocking_instance, l.inst_id)
 start with (s.inst_id, s.sid) in (select inst_id, sid from BLOCKERS minus select inst_id, sid from WAITERS)
/
set feedback on echo off VERIFY ON

