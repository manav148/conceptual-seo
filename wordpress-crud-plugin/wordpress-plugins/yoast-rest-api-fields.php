<?php
/**
 * Plugin Name: Yoast SEO REST API Fields
 * Description: Exposes Yoast SEO meta fields for reading and writing via the WordPress REST API. Required for Claude Code's WordPress CRUD plugin to manage SEO fields.
 * Version: 1.0.0
 * Author: Manav Kundra
 * License: MIT
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', 'yoast_rest_register_fields');

function yoast_rest_register_fields() {
    $post_types = ['post', 'page'];

    $yoast_fields = [
        'yoast_title'              => '_yoast_wpseo_title',
        'yoast_metadesc'           => '_yoast_wpseo_metadesc',
        'yoast_focuskw'            => '_yoast_wpseo_focuskw',
        'yoast_canonical'          => '_yoast_wpseo_canonical',
        'yoast_noindex'            => '_yoast_wpseo_meta-robots-noindex',
        'yoast_nofollow'           => '_yoast_wpseo_meta-robots-nofollow',
        'yoast_og_title'           => '_yoast_wpseo_opengraph-title',
        'yoast_og_description'     => '_yoast_wpseo_opengraph-description',
        'yoast_og_image'           => '_yoast_wpseo_opengraph-image',
        'yoast_twitter_title'      => '_yoast_wpseo_twitter-title',
        'yoast_twitter_description'=> '_yoast_wpseo_twitter-description',
        'yoast_twitter_image'      => '_yoast_wpseo_twitter-image',
        'yoast_schema_page_type'   => '_yoast_wpseo_schema_page_type',
        'yoast_schema_article_type'=> '_yoast_wpseo_schema_article_type',
        'yoast_is_cornerstone'     => '_yoast_wpseo_is_cornerstone',
        'yoast_breadcrumb_title'   => '_yoast_wpseo_bctitle',
        'yoast_robots_advanced'    => '_yoast_wpseo_meta-robots-adv',
    ];

    foreach ($post_types as $post_type) {
        foreach ($yoast_fields as $rest_key => $meta_key) {
            register_rest_field($post_type, $rest_key, [
                'get_callback'    => function ($post) use ($meta_key) {
                    return get_post_meta($post['id'], $meta_key, true);
                },
                'update_callback' => function ($value, $post) use ($meta_key) {
                    return update_post_meta($post->ID, $meta_key, sanitize_text_field($value));
                },
                'schema'          => [
                    'type'        => 'string',
                    'description' => "Yoast SEO field: {$meta_key}",
                    'context'     => ['view', 'edit'],
                ],
            ]);
        }
    }
}
