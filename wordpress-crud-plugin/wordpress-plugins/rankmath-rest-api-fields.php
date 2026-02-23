<?php
/**
 * Plugin Name: RankMath REST API Fields
 * Description: Exposes RankMath SEO meta fields for reading and writing via the WordPress REST API. Required for Claude Code's WordPress CRUD plugin to manage RankMath SEO fields.
 * Version: 1.0.0
 * Author: Manav Kundra
 * License: MIT
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', 'rankmath_rest_register_fields');

function rankmath_rest_register_fields() {
    $post_types = ['post', 'page'];

    // String fields
    $string_fields = [
        'rank_math_title',
        'rank_math_description',
        'rank_math_focus_keyword',
        'rank_math_canonical_url',
        'rank_math_breadcrumb_title',
        'rank_math_facebook_title',
        'rank_math_facebook_description',
        'rank_math_facebook_image',
        'rank_math_twitter_title',
        'rank_math_twitter_description',
        'rank_math_twitter_image',
        'rank_math_twitter_card_type',
        'rank_math_twitter_use_facebook',
        'rank_math_pillar_content',
        'rank_math_rich_snippet',
        'rank_math_snippet_article_type',
        'rank_math_redirect_url',
        'rank_math_redirect_type',
    ];

    // URL fields need esc_url_raw sanitization
    $url_fields = [
        'rank_math_canonical_url',
        'rank_math_redirect_url',
        'rank_math_facebook_image',
        'rank_math_twitter_image',
    ];

    foreach ($post_types as $post_type) {
        foreach ($string_fields as $key) {
            $sanitize = in_array($key, $url_fields, true) ? 'esc_url_raw' : 'sanitize_text_field';

            register_post_meta($post_type, $key, [
                'show_in_rest'      => true,
                'single'            => true,
                'type'              => 'string',
                'auth_callback'     => function () {
                    return current_user_can('edit_posts');
                },
                'sanitize_callback' => $sanitize,
            ]);
        }

        // Integer fields
        foreach (['rank_math_facebook_image_id', 'rank_math_primary_category'] as $key) {
            register_post_meta($post_type, $key, [
                'show_in_rest'      => true,
                'single'            => true,
                'type'              => 'integer',
                'auth_callback'     => function () {
                    return current_user_can('edit_posts');
                },
                'sanitize_callback' => 'absint',
            ]);
        }

        // Array field: rank_math_robots
        register_post_meta($post_type, 'rank_math_robots', [
            'show_in_rest' => [
                'schema' => [
                    'type'  => 'array',
                    'items' => ['type' => 'string'],
                ],
            ],
            'single'        => true,
            'type'          => 'array',
            'auth_callback' => function () {
                return current_user_can('edit_posts');
            },
        ]);
    }
}
