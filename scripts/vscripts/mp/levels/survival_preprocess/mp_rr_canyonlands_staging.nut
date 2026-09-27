global function mp_rr_canyonlands_staging_SurvivalPreprocess
global function RunMySurvivalPreprocess

void function RunMySurvivalPreprocess()
{
	mp_rr_canyonlands_staging_SurvivalPreprocess()
}

void function mp_rr_canyonlands_staging_SurvivalPreprocess()
{
	if ( Dev_CommandLineHasParm( "-survival_preprocess" ) )
		return

	SURVIVAL_MarkLevelAsPreProcessed()
}
