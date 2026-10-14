# Copyright (C) 2026 Vertel AB (<https://vertel.se>).
# License AGPL-3.0 or later.
from odoo import models, api


class WebsiteMenu(models.Model):
    _inherit = 'website.menu'

    @api.model
    def _businessmassan_clean_default_menu(self):
        """Ta bort Odoos standardmenyposter ur Businessmässans meny.

        Odoo skapar en global standardmeny ("Default Main Menu", website_id = NULL)
        med standardposter (Shop, Events, Forum, Courses, Booking, Event Types).
        Den är inte knuten till någon webbplats och syns därför inte på sajten —
        men den ligger kvar och skräpar i databasen.

        VIKTIGT: /contactus tas INTE bort — kundens kontaktsida ÄR /contactus
        (website.contactus). Att matcha den på url skulle radera kundens sida.

        Idempotent: körs vid varje moduluppdatering, raderar bara om de finns.
        """
        default_urls = [
            '/shop', '/event', '/forum', '/event-types', '/slides',
            '/website/calendar',
        ]
        menus = self.search([('url', 'in', default_urls)])
        if menus:
            menus.unlink()
        return True
