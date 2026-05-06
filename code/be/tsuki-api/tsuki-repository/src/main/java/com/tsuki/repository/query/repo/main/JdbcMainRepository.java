package com.tsuki.repository.query.repo.main;

import com.tsuki.common.util.ListUtils;
import com.tsuki.repository.query.dto.main.MainInfoDTO;
import jakarta.annotation.Resource;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcMainRepository {

    private static final String QUERY_MAIN_SQL = """
            SELECT id, kanji, hiragana, sentence, tokens, updated
              FROM tsuki_main
             WHERE kanji = ?
              ORDER BY updated DESC
             LIMIT 1
            """;

    private static final String QUERY_MAIN_BY_ID_SQL = """
            SELECT id, kanji, hiragana, sentence, tokens, updated
              FROM tsuki_main
             WHERE id = ?
             LIMIT 1
            """;

    @Resource
    private JdbcTemplate jdbcTemplate;

    public MainInfoDTO findLatestByKanji(String word) {
        List<MainInfoDTO> mainInfoList = jdbcTemplate.query(
                QUERY_MAIN_SQL,
                (rs, rowNum) -> new MainInfoDTO(
                        rs.getInt("id"),
                        rs.getString("kanji"),
                        rs.getString("hiragana"),
                        rs.getString("sentence"),
                        rs.getString("tokens"),
                        rs.getInt("updated")
                ),
                word
        );

        if (mainInfoList.isEmpty()) {
            return null;
        }

        return ListUtils.first(mainInfoList);
    }

    public MainInfoDTO findById(Integer wordId) {
        List<MainInfoDTO> mainInfoList = jdbcTemplate.query(
                QUERY_MAIN_BY_ID_SQL,
                (rs, rowNum) -> new MainInfoDTO(
                        rs.getInt("id"),
                        rs.getString("kanji"),
                        rs.getString("hiragana"),
                        rs.getString("sentence"),
                        rs.getString("tokens"),
                        rs.getInt("updated")
                ),
                wordId
        );

        if (mainInfoList.isEmpty()) {
            return null;
        }

        return ListUtils.first(mainInfoList);
    }
}
