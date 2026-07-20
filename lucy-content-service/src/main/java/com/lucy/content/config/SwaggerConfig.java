package com.lucy.content.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SwaggerConfig {

    @Bean
    public OpenAPI lucyOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("LUCY Content & LMS API")
                .description("""
                    API quản lý nội dung học ngôn ngữ của dự án LUCY.
                    - 3 ngôn ngữ: English, Chinese, Japanese
                    - 100 Levels chia làm 3 Stage (Sơ cấp / Trung cấp / Cao cấp)
                    - Mỗi level có 6 sub-levels với câu hỏi & câu trả lời mẫu
                    """)
                .version("1.0.0")
                .contact(new Contact()
                    .name("LUCY Dev Team")
                    .email("dev@lucy.edu.vn"))
                .license(new License()
                    .name("FPT University – PRJ301")
                    .url("https://fpt.edu.vn")));
    }
}
