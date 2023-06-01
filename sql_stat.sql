--
-- SQL statistics by cursor / plan from Shared Pool
-- Usage: SQL> @sql_stat &sql_id
--

set verify off lines 200

select
    st.inst_id,
    st.sql_id,
    st.child_number,
    st.plan_hash_value as plan,
    st.optimizer_cost,
    round(st.executions) as execs,
    round(st.elapsed_time/st.executions) as ela_per_exec,
    round(st.cpu_time/st.executions) as cpu_per_exec,
    round(st.user_io_wait_time/st.executions) as iowaits_per_exec,
    round(st.application_wait_time/st.executions) as appwaits_per_exec,
    round(st.concurrency_wait_time/st.executions) as ccwaits_per_exec,
    round(st.cluster_wait_time/st.executions) as clwaits_per_exec,
    round(st.buffer_gets/st.executions) as buffer_gets_per_exec,
--    round(st.direct_writes/st.executions) as direct_writes_per_exec,
    round(st.rows_processed/st.executions) as rows_per_exec,
    round(st.fetches/st.executions) as fetch_per_exec,
    round(st.px_servers_executions/st.executions) as px_per_exec,
    st.*
from gv$sql st
where sql_id = '&1'
/
set verify on
