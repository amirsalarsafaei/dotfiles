pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var months: ["Farvardin", "Ordibehesht", "Khordad", "Tir", "Mordad", "Shahrivar", "Mehr", "Aban", "Azar", "Dey", "Bahman", "Esfand"]

    function of(date: date): var {
        const offsets = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
        const gy = date.getFullYear();
        const gm = date.getMonth() + 1;
        const gy2 = gm > 2 ? gy + 1 : gy;
        let days = 355666 + 365 * gy + Math.floor((gy2 + 3) / 4) - Math.floor((gy2 + 99) / 100) + Math.floor((gy2 + 399) / 400) + date.getDate() + offsets[gm - 1];
        let jy = -1595 + 33 * Math.floor(days / 12053);
        days %= 12053;
        jy += 4 * Math.floor(days / 1461);
        days %= 1461;
        if (days > 365) {
            jy += Math.floor((days - 1) / 365);
            days = (days - 1) % 365;
        }
        const jm = days < 186 ? 1 + Math.floor(days / 31) : 7 + Math.floor((days - 186) / 30);
        const jd = days < 186 ? 1 + days % 31 : 1 + (days - 186) % 30;
        return {
            year: jy,
            month: jm,
            day: jd
        };
    }
}
