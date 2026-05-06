package com.tsuki.api.helper;

import com.tsuki.common.dto.QueryDsResult;
import com.tsuki.common.enums.LangType;
import com.tsuki.common.request.QueryDsRequest;
import com.tsuki.common.response.BaseResponse;
import org.springframework.stereotype.Component;

@Component
public class ValidationHelper {

    public BaseResponse<QueryDsResult> validateQueryDsRequest(QueryDsRequest request) {
        if (!LangType.isSupported(request.getLang())) {
            return BaseResponse.fail(400, "invalid lang, supported: cn, tw, en, ja");
        }
        return null;
    }
}
