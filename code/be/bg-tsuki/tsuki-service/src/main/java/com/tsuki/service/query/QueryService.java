package com.tsuki.service.query;

import com.tsuki.common.dto.QueryDsResult;
import com.tsuki.common.request.QueryDsRequest;

public interface QueryService {

    QueryDsResult queryDs(QueryDsRequest request);
}
