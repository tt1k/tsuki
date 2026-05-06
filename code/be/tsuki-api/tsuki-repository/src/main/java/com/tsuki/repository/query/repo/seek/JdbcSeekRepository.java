package com.tsuki.repository.query.repo.seek;

import com.tsuki.common.util.ListUtils;
import com.tsuki.repository.query.dto.seek.SeekInfoDTO;
import jakarta.annotation.Resource;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcSeekRepository {

    private static final String QUERY_SEEK_BY_TERM_SQL = """
            SELECT word_id, lang, term, updated
              FROM tsuki_seek
             WHERE term = ?
             ORDER BY updated DESC, id DESC
             LIMIT 1
            """;

    private static final String QUERY_SEEK_SQL = """
            SELECT word_id, lang, term, updated
              FROM tsuki_seek
             WHERE word_id = ?
               AND lang = ?
             ORDER BY updated DESC, id DESC
            """;

    @Resource
    private JdbcTemplate jdbcTemplate;

    public List<SeekInfoDTO> findByWordIdAndLang(Integer wordId, String lang) {
        return jdbcTemplate.query(
                QUERY_SEEK_SQL,
                (rs, rowNum) -> new SeekInfoDTO(
                        rs.getInt("word_id"),
                        rs.getString("lang"),
                        rs.getString("term"),
                        rs.getInt("updated")
                ),
                wordId,
                lang
        );
    }

    public SeekInfoDTO findLatestByTerm(String term) {
        List<SeekInfoDTO> seekInfoList = jdbcTemplate.query(
                QUERY_SEEK_BY_TERM_SQL,
                (rs, rowNum) -> new SeekInfoDTO(
                        rs.getInt("word_id"),
                        rs.getString("lang"),
                        rs.getString("term"),
                        rs.getInt("updated")
                ),
                term
        );

        if (seekInfoList.isEmpty()) {
            return null;
        }

        return ListUtils.first(seekInfoList);
    }
}
