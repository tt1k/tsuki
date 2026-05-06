package com.tsuki.repository.query.dto;

import com.tsuki.repository.query.dto.main.MainInfoDTO;
import com.tsuki.repository.query.dto.mean.MeanInfoDTO;
import io.swagger.annotations.ApiModelProperty;
import java.io.Serializable;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class RepoQueryResult implements Serializable {

    @ApiModelProperty("main info dto")
    private MainInfoDTO mainInfoDTO;

    @ApiModelProperty("mean info dto")
    private MeanInfoDTO meanInfoDTO;
}
