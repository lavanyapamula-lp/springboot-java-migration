package com.example;

import net.sf.log4jdbc.sql.jdbcapi.DataSourceSpy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;

@Configuration
public class AppConfig {

    @Bean
    @ConfigurationProperties(prefix = "spring.datasource")
    DataSource realDataSource(@Value("${spring.datasource.url:jdbc:h2:mem:testdb}") String url) {
        return DataSourceBuilder
                .create()
                .url(url)
                .build();
    }

    @Bean
    @Primary
    DataSource dataSource() {
        return new DataSourceSpy(realDataSource(null));
    }
}