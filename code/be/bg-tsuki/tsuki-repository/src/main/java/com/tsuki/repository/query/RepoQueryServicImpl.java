package com.tsuki.repository.query;

import com.tsuki.repository.query.dto.main.MainInfoDTO;
import com.tsuki.repository.query.dto.mean.MeanInfoDTO;
import com.tsuki.repository.query.dto.RepoQueryResult;
import com.tsuki.repository.query.dto.seek.SeekInfoDTO;
import com.tsuki.repository.query.repo.main.JdbcMainRepository;
import com.tsuki.repository.query.repo.mean.JdbcMeanRepository;
import com.tsuki.repository.query.repo.seek.JdbcSeekRepository;
import jakarta.annotation.Resource;
import java.util.Objects;
import org.springframework.stereotype.Repository;

@Repository
public class RepoQueryServicImpl implements RepoQueryService {

    @Resource
    private JdbcMainRepository jdbcMainRepository;

    @Resource
    private JdbcMeanRepository jdbcMeanRepository;

    @Resource
    private JdbcSeekRepository jdbcSeekRepository;

    @Override
    public RepoQueryResult findByKanjiAndLang(String word, String lang) {
        MainInfoDTO mainInfoDTO = jdbcMainRepository.findLatestByKanji(word);
        if (Objects.isNull(mainInfoDTO)) {
            return null;
        }

        return buildQueryInfoResult(mainInfoDTO, lang);
    }

    @Override
    public RepoQueryResult findBySeekTermAndLang(String word, String lang) {
        SeekInfoDTO seekInfoDTO = jdbcSeekRepository.findLatestByTerm(word);
        if (Objects.isNull(seekInfoDTO)) {
            return null;
        }

        MainInfoDTO mainInfoDTO = jdbcMainRepository.findById(seekInfoDTO.getWordId());
        if (Objects.isNull(mainInfoDTO)) {
            return null;
        }

        return buildQueryInfoResult(mainInfoDTO, lang);
    }

    private RepoQueryResult buildQueryInfoResult(MainInfoDTO mainInfoDTO, String lang) {
        MeanInfoDTO meanInfoDTO = jdbcMeanRepository.findByWordIdAndLang(mainInfoDTO.getId(), lang);
        if (Objects.isNull(meanInfoDTO)) {
            return null;
        }

        return new RepoQueryResult(mainInfoDTO, meanInfoDTO);
    }
}
