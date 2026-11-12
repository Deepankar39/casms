'use strict';
// Never expose raw SQL or internal stack traces through API responses.
function errorHandler(err,req,res,next){
  if(res.headersSent)return next(err);
  const mysql=err?.errno||err?.code;
  let status=err.status||500;
  let message=status<500?err.message:'Something went wrong. Please try again.';
  if(mysql===1062||mysql==='ER_DUP_ENTRY'){status=409;message='A record with this unique value already exists.';}
  else if(mysql===1452||mysql==='ER_NO_REFERENCED_ROW_2'){status=400;message='Choose an existing related record.';}
  else if(mysql===1451||mysql==='ER_ROW_IS_REFERENCED_2'){status=409;message='This record is in use and cannot be removed.';}
  else if(mysql===3819||mysql==='ER_CHECK_CONSTRAINT_VIOLATED'){status=400;message='One or more values violate a database rule.';}
  else if(mysql===1644||mysql==='ER_SIGNAL_EXCEPTION'){status=400;
    const allowed=/^(Only Admin|Invalid|Asset |Cannot |Current |Request |Technician |Staff |User |Already |Maintenance |Closed |Cancelled |Admin and|Assigned |Set parent|Cyclic |Retired |No |Parts |Start |Negative )/;
    message=allowed.test(err.sqlMessage||'')?(err.sqlMessage||'Business rule rejected this change.'):'Business rule rejected this change.';
  }
  console.error('[CASMS]',err.code||err.name||'Error',err.message);
  res.status(status).json({error:message});
}
module.exports={errorHandler};
