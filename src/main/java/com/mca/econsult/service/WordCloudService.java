package com.mca.econsult.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.*;

@Service
public class WordCloudService {

    @Value("${ai.service.url}")
    private String aiServiceUrl;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * Sends texts to the Python AI service to generate a word cloud image.
     *
     * @param texts list of comment strings
     * @return path to the generated word cloud image
     */
    public String generateWordCloud(List<String> texts) {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("texts", texts);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

        try {
            ResponseEntity<String> response = restTemplate.postForEntity(
                    aiServiceUrl + "/wordcloud", entity, String.class);

            Map<String, Object> result = objectMapper.readValue(response.getBody(), Map.class);
            // Handle both new wrapped format {"success":true,"data":{"path":"..."}}
            // and legacy flat format {"path":"..."}
            Object dataObj = result.get("data");
            if (dataObj instanceof Map) {
                Map<String, Object> data = (Map<String, Object>) dataObj;
                return (String) data.get("path");
            }
            return (String) result.get("path");
        } catch (Exception e) {
            return null;
        }
    }
}
