package com.tsuki.repository.query.dto.main;

import io.swagger.annotations.ApiModelProperty;
import java.io.Serializable;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class MainInfoDTO implements Serializable {

    @ApiModelProperty("word id")
    private Integer id;

    @ApiModelProperty("kanji word")
    private String kanji;

    @ApiModelProperty("hiragana spelling")
    private String hiragana;

    @ApiModelProperty("example sentence")
    private String sentence;

    @ApiModelProperty("token json")
    private String tokens;

    @ApiModelProperty("updated timestamp")
    private Integer updated;
}
