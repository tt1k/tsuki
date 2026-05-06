package com.tsuki.common.dto;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QueryDsResult {

    private String lang;
    private Sentence sentence;
    private Kanji kanji;
    private List<TokenItem> tokens;
}
