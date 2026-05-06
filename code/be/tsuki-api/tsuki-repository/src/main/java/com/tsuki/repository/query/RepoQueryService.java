package com.tsuki.repository.query;

import com.tsuki.repository.query.dto.RepoQueryResult;

public interface RepoQueryService {

    RepoQueryResult findByKanjiAndLang(String word, String lang);

    RepoQueryResult findBySeekTermAndLang(String word, String lang);
}
