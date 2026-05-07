package com.tsuki.repository.query.dto.mean;

import io.swagger.annotations.ApiModelProperty;
import java.io.Serializable;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class MeanInfoDTO implements Serializable {

    @ApiModelProperty("word id")
    private Integer wordId;

    @ApiModelProperty("language code")
    private String lang;

    @ApiModelProperty("word meaning")
    private String meanW;

    @ApiModelProperty("sentence meaning")
    private String meanS;

    @ApiModelProperty("updated timestamp")
    private Integer updated;
}
