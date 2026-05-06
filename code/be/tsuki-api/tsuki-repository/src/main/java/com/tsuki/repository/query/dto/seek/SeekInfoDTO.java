package com.tsuki.repository.query.dto.seek;

import io.swagger.annotations.ApiModelProperty;
import java.io.Serializable;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class SeekInfoDTO implements Serializable {

    @ApiModelProperty("word id")
    private Integer wordId;

    @ApiModelProperty("language code")
    private String lang;

    @ApiModelProperty("seek term")
    private String term;

    @ApiModelProperty("updated timestamp")
    private Integer updated;
}
