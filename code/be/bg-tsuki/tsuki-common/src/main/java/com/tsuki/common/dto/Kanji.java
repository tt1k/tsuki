package com.tsuki.common.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Kanji {

    private String text;
    private String mean;
    private String hiragana;
}
