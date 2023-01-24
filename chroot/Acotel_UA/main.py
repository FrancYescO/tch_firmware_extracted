#------------------------------------------------------------------------------
#
# Acotel_UA
#
# main.py  
#
# Last update : 2021-11-05 
#
# 2022-01-10 V1.1.1 FR :
#------------------------------------------------------------------------------
import asyncio
import TRACER as tracer
import run_main

try:
    asyncio.run(run_main.main())
except Exception as err:
    tracer.Info("asyncio.run(main()) exception : " + str(err))
    
