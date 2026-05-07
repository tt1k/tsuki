package com.tsuki.api.controller;

import com.tsuki.api.helper.ValidationHelper;
import com.tsuki.common.dto.QueryDsResult;
import com.tsuki.common.request.QueryDsRequest;
import com.tsuki.common.response.BaseResponse;
import com.tsuki.service.query.QueryService;
import jakarta.annotation.Resource;
import java.util.Objects;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/query")
public class QueryController {

    @Resource
    private QueryService queryService;

    @Resource
    private ValidationHelper validationHelper;

    @GetMapping("/ds")
    public BaseResponse<QueryDsResult> queryDs(QueryDsRequest request) {
        BaseResponse<QueryDsResult> validationResult = validationHelper.validateQueryDsRequest(request);
        if (Objects.nonNull(validationResult)) {
            return validationResult;
        }
        return BaseResponse.success(queryService.queryDs(request));
    }

}
