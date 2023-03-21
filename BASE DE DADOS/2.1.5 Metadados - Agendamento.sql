USE msdb;
GO

-- Define um job com um nome exclusivo
EXEC dbo.sp_add_job
    @job_name = 'MonitoringData';

-- Define o primeiro passo do job para executar a procedure WWIGlobal.WWI.sp_monitoringstorage
EXEC sp_add_jobstep
    @job_name = 'MonitoringData',
    @step_name = 'Executar WWIGlobal.WWI.sp_monitoringstorage',
    @subsystem = 'TSQL',
    @command = 'EXEC WWIGlobal.WWI.sp_monitoringstorage;',
    @retry_attempts = 0,
    @on_success_action = 1;

-- Define o segundo passo do job para executar a procedure WWIGlobal.WWI.sp_monitoring
EXEC sp_add_jobstep
    @job_name = 'MonitoringData',
    @step_name = 'Executar WWIGlobal.WWI.sp_monitoring',
    @subsystem = 'TSQL',
    @command = 'EXEC WWIGlobal.WWI.sp_monitoring;',
    @retry_attempts = 0,
    @on_success_action = 1;

-- Define um agendamento diário para o job
EXEC dbo.sp_add_schedule
    @schedule_name = 'AgendamentoDiario',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = '000000';

-- Associa o agendamento ao job
EXEC sp_attach_schedule
   @job_name = 'MonitoringData',
   @schedule_name = 'AgendamentoDiario';

-- Habilita o job
EXEC dbo.sp_update_job
    @job_name = 'MonitoringData',
    @enabled = 1;
