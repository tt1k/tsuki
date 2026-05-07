package com.tsuki.repository.query.repo.mean;

import com.tsuki.common.util.ListUtils;
import com.tsuki.repository.query.dto.mean.MeanInfoDTO;
import jakarta.annotation.Resource;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcMeanRepository {

    private static final String QUERY_MEAN_SQL = """
            SELECT word_id, lang, mean_w, mean_s, updated
              FROM tsuki_mean
             WHERE word_id = ?
               AND lang = ?
             LIMIT 1
            """;

    @Resource
    private JdbcTemplate jdbcTemplate;

    public MeanInfoDTO findByWordIdAndLang(Integer wordId, String lang) {
        List<MeanInfoDTO> meanInfoList = jdbcTemplate.query(
                QUERY_MEAN_SQL,
                (rs, rowNum) -> new MeanInfoDTO(
                        rs.getInt("word_id"),
                        rs.getString("lang"),
                        rs.getString("mean_w"),
                        rs.getString("mean_s"),
                        rs.getInt("updated")
                ),
                wordId,
                lang
        );

        if (meanInfoList.isEmpty()) {
            return null;
        }

        return ListUtils.first(meanInfoList);
    }
}
