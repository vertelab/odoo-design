{
    'name': 'Businessmässan Website',
    'version': '18.0.1.23.0',
    'summary': 'Businessmässan (Anders Björck AB) — Odoo website.',
    'category': 'Website/Website',
    'author': 'Vertel AB',
    'website': 'https://vertel.se/apps/odoo-design/businessmassan_website',
    'license': 'AGPL-3',
    'depends': ['website'],
    'data': [
        'data/ir_asset.xml',
        'data/website_pages.xml',
        'data/website_config.xml',
        'data/website_menu.xml',
        'views/website_footer.xml',
        'views/website_contactus.xml',
    ],
    'assets': {
        'web.assets_frontend': [
            'businessmassan_website/static/src/scss/businessmassan.scss',
        ],
    },
    'installable': True,
    'application': False,
}
