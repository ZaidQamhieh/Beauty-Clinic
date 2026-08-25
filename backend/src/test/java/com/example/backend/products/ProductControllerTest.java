package com.example.backend.products;

import com.example.backend.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class ProductControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminCanCreateUpdateAndDeleteProduct() throws Exception {
        String body = mockMvc.perform(post("/api/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Retinol Complex","brand":"ZO_SKIN_HEALTH","productType":"RETINOID",
                                 "imageUrl":"https://example.com/retinol.jpg",
                                 "stockQuantity":12,"ingredients":["CERAMIDES"]}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Retinol Complex"))
                .andExpect(jsonPath("$.imageUrl").value("https://example.com/retinol.jpg"))
                .andExpect(jsonPath("$.stockQuantity").value(12))
                .andReturn().getResponse().getContentAsString();
        String id = JsonPath.read(body, "$.id");

        mockMvc.perform(put("/api/products/{id}", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Daily Hydration","brand":"ZO_SKIN_HEALTH","productType":"MOISTURIZER",
                                 "stockQuantity":8,"ingredients":["CERAMIDES","HYALURONIC_ACID"]}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.productType").value("MOISTURIZER"))
                .andExpect(jsonPath("$.stockQuantity").value(8));

        mockMvc.perform(delete("/api/products/{id}", id))
                .andExpect(status().isNoContent());
        mockMvc.perform(get("/api/products/{id}", id))
                .andExpect(status().isNotFound());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void rejectsNegativeStock() throws Exception {
        mockMvc.perform(post("/api/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Hydrating Cleanser","brand":"CERAVE","productType":"CLEANSER",
                                 "stockQuantity":-1,"ingredients":[]}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void doctorCanCreateUpdateAndDeleteProduct() throws Exception {
        String body = mockMvc.perform(post("/api/products")
        .contentType(MediaType.APPLICATION_JSON)
        .content("""
                {"name":"Retinol Complex","brand":"ZO_SKIN_HEALTH","productType":"RETINOID",
                "stockQuantity":5,"ingredients":["CERAMIDES"]}
                """))
        .andExpect(status().isCreated())
        .andReturn().getResponse().getContentAsString();

        String id = JsonPath.read(body, "$.id");

        mockMvc.perform(put("/api/products/{id}", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Daily Hydration","brand":"ZO_SKIN_HEALTH","productType":"MOISTURIZER",
                                "stockQuantity":10,"ingredients":["CERAMIDES"]}
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(delete("/api/products/{id}", id))
                .andExpect(status().isNoContent());
    }
}
