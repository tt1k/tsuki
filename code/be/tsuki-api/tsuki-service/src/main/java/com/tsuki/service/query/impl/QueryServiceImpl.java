package com.tsuki.service.query.impl;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tsuki.common.dto.Kanji;
import com.tsuki.common.dto.QueryDsResult;
import com.tsuki.common.dto.Sentence;
import com.tsuki.common.dto.TokenItem;
import com.tsuki.common.request.QueryDsRequest;
import com.tsuki.repository.query.RepoQueryService;
import com.tsuki.repository.query.dto.RepoQueryResult;
import com.tsuki.service.query.QueryService;
import jakarta.annotation.Resource;
import java.util.List;
import java.util.Objects;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Service;

@Service
public class QueryServiceImpl implements QueryService {

    private static final TypeReference<List<TokenItem>> TOKENS_TYPE = new TypeReference<>() {
    };

    @Resource
    private RepoQueryService repoQueryService;

    @Resource
    private ObjectMapper objectMapper;

    @Override
    public QueryDsResult queryDs(QueryDsRequest request) {
        RepoQueryResult repoQueryResult = isJapaneseWord(request.getWord())
                ? repoQueryService.findByKanjiAndLang(request.getWord(), request.getLang())
                : repoQueryService.findBySeekTermAndLang(request.getWord(), request.getLang());
        if (Objects.isNull(repoQueryResult)) {
            return null;
        }
        return toPayload(repoQueryResult);
    }

    private QueryDsResult toPayload(RepoQueryResult repoQueryResult) {
        List<TokenItem> tokens = parseTokens(repoQueryResult.getMainInfoDTO().getTokens());
        Sentence sentence = new Sentence(repoQueryResult.getMainInfoDTO().getSentence(), repoQueryResult.getMeanInfoDTO().getMeanS());
        Kanji kanji = new Kanji(repoQueryResult.getMainInfoDTO().getKanji(), repoQueryResult.getMeanInfoDTO().getMeanW(), repoQueryResult.getMainInfoDTO().getHiragana());
        return QueryDsResult.builder()
                .lang(repoQueryResult.getMeanInfoDTO().getLang())
                .sentence(sentence)
                .kanji(kanji)
                .tokens(tokens)
                .build();
    }

    private List<TokenItem> parseTokens(String tokens) {
        try {
            return objectMapper.readValue(tokens, TOKENS_TYPE);
        } catch (Exception ex) {
            throw new IllegalStateException("Failed to parse tokens JSON", ex);
        }
    }

    private boolean isJapaneseWord(String word) {
        if (StringUtils.isBlank(word)) {
            return false;
        }

        return word.codePoints().anyMatch(codePoint -> {
            Character.UnicodeBlock block = Character.UnicodeBlock.of(codePoint);
            return block == Character.UnicodeBlock.HIRAGANA
                    || block == Character.UnicodeBlock.KATAKANA
                    || block == Character.UnicodeBlock.KATAKANA_PHONETIC_EXTENSIONS
                    || block == Character.UnicodeBlock.HALFWIDTH_AND_FULLWIDTH_FORMS;
        });
    }
}
