{
    'name': 'Businessmässan Website',
    'version': '18.0.1.16.0',
    'summary': 'Kopia av businessmassan.se som Odoo-webbplats.',
    'category': 'Website/Website',
    'author': 'Vertel AB',
    'website': 'https://vertel.se',
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
