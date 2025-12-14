
import Foundation
import UIKit

// MARK: --- Primary Colors (Green) ---
enum Token {
    @ColorElement(light: UIColor.from("#DCF3DC"), dark: UIColor.from("#101410"))
    static var primary50: UIColor
    
    @ColorElement(light: UIColor.from("#DCF3DC"), dark: UIColor.from("#DCF3DC"))
    static var primary100: UIColor
    
    @ColorElement(light: UIColor.from("#98D098"), dark: UIColor.from("#98D098"))
    static var primary200: UIColor
    
    @ColorElement(light: UIColor.from("#60A060"), dark: UIColor.from("#60A060"))
    static var primary300: UIColor
    
    @ColorElement(light: UIColor.from("#308030"), dark: UIColor.from("#308030"))
    static var primary400: UIColor
    
    @ColorElement(light: UIColor.from("#16610E"), dark: UIColor.from("#16610E"))
    static var primary500: UIColor
    
    @ColorElement(light: UIColor.from("#14550C"), dark: UIColor.from("#14550C"))
    static var primary600: UIColor
    
    @ColorElement(light: UIColor.from("#11490B"), dark: UIColor.from("#14550C"))
    static var primary700: UIColor
    
    @ColorElement(light: UIColor.from("#11490B"), dark: UIColor.from("#11490B"))
    static var primary800: UIColor
    
    @ColorElement(light: UIColor.from("#0D3508"), dark: UIColor.from("#101410"))
    static var primary900: UIColor
}

// MARK: --- Accent Colors (Orange) ---
extension Token {
    @ColorElement(light: UIColor.from("#FEF2E6"), dark: UIColor.from("#FEF2E6"))
    static var accent50: UIColor
    
    @ColorElement(light: UIColor.from("#FFD0A0"), dark: UIColor.from("#FFD0A0"))
    static var accent100: UIColor
    
    @ColorElement(light: UIColor.from("#FFB070"), dark: UIColor.from("#FFB070"))
    static var accent200: UIColor
    
    @ColorElement(light: UIColor.from("#FA9040"), dark: UIColor.from("#FA9040"))
    static var accent300: UIColor
    
    @ColorElement(light: UIColor.from("#FC8020"), dark: UIColor.from("#FC8020"))
    static var accent400: UIColor
    
    @ColorElement(light: UIColor.from("#F97A00"), dark: UIColor.from("#E07000"))
    static var accent500: UIColor
    
    @ColorElement(light: UIColor.from("#D06500"), dark: UIColor.from("#D06500"))
    static var accent600: UIColor
    
    @ColorElement(light: UIColor.from("#BB5C00"), dark: UIColor.from("#BB5C00"))
    static var accent700: UIColor
    
    @ColorElement(light: UIColor.from("#A05000"), dark: UIColor.from("#A05000"))
    static var accent800: UIColor
    
    @ColorElement(light: UIColor.from("#804000"), dark: UIColor.from("#804000"))
    static var accent900: UIColor
}

// MARK: --- Black & White Colors ---
extension Token {
    @ColorElement(light: UIColor.from("#FFFFFF"), dark: UIColor.from("#FFFFFF"))
    static var white: UIColor
    
    @ColorElement(light: UIColor.from("#F7F7F7"), dark: UIColor.from("#F7F7F7"))
    static var whiteF7: UIColor
    
    @ColorElement(light: UIColor.from("#161616"), dark: UIColor.from("#161616"))
    static var black: UIColor
}

// MARK: - Warning Colors
extension Token {
    @ColorElement(light: UIColor.from("#FFF9E6"), dark: UIColor.from("#3E3218"))
    static var warning50: UIColor
    
    @ColorElement(light: UIColor.from("#FFECB2"), dark: UIColor.from("#FFECB2"))
    static var warning100: UIColor
    
    @ColorElement(light: UIColor.from("#FFE28D"), dark: UIColor.from("#FFE28D"))
    static var warning200: UIColor
    
    @ColorElement(light: UIColor.from("#FED559"), dark: UIColor.from("#FFF59D"))
    static var warning300: UIColor
    
    @ColorElement(light: UIColor.from("#FECD39"), dark: UIColor.from("#FECD39"))
    static var warning400: UIColor
    
    @ColorElement(light: UIColor.from("#FEC107"), dark: UIColor.from("#FEC107"))
    static var warning500: UIColor
    
    @ColorElement(light: UIColor.from("#E7B006"), dark: UIColor.from("#E7B006"))
    static var warning600: UIColor
    
    @ColorElement(light: UIColor.from("#E7B006"), dark: UIColor.from("#E7B006"))
    static var warning650: UIColor
    
    @ColorElement(light: UIColor.from("#B48905"), dark: UIColor.from("#B48905"))
    static var warning700: UIColor
    
    @ColorElement(light: UIColor.from("#8C6A04"), dark: UIColor.from("#FFF176"))
    static var warning800: UIColor
    
    @ColorElement(light: UIColor.from("#6B5103"), dark: UIColor.from("#6B5103"))
    static var warning900: UIColor
}

// MARK: - Success Colors
extension Token {
    @ColorElement(light: UIColor.from("#EDF7EE"), dark: UIColor.from("#1B3320"))
    static var success50: UIColor
    
    @ColorElement(light: UIColor.from("#C8E7C9"), dark: UIColor.from("#C8E7C9"))
    static var success100: UIColor
    
    @ColorElement(light: UIColor.from("#ADDBAF"), dark: UIColor.from("#ADDBAF"))
    static var success200: UIColor
    
    @ColorElement(light: UIColor.from("#87CA8A"), dark: UIColor.from("#81C784"))
    static var success300: UIColor
    
    @ColorElement(light: UIColor.from("#70C073"), dark: UIColor.from("#70C073"))
    static var success400: UIColor
    
    @ColorElement(light: UIColor.from("#4CB050"), dark: UIColor.from("#4CB050"))
    static var success500: UIColor
    
    @ColorElement(light: UIColor.from("#45A049"), dark: UIColor.from("#45A049"))
    static var success600: UIColor
    
    @ColorElement(light: UIColor.from("#367D39"), dark: UIColor.from("#A5D6A7"))
    static var success700: UIColor
    
    @ColorElement(light: UIColor.from("#2A612C"), dark: UIColor.from("#2A612C"))
    static var success800: UIColor
    
    @ColorElement(light: UIColor.from("#204A22"), dark: UIColor.from("#204A22"))
    static var success900: UIColor
}

// MARK: - Error Colors
extension Token {
    @ColorElement(light: UIColor.from("#FEECEB"), dark: UIColor.from("#3E2723"))
    static var error50: UIColor
    
    @ColorElement(light: UIColor.from("#FCC5C1"), dark: UIColor.from("#FCC5C1"))
    static var error100: UIColor
    
    @ColorElement(light: UIColor.from("#FAA9A3"), dark: UIColor.from("#FAA9A3"))
    static var error200: UIColor
    
    @ColorElement(light: UIColor.from("#F88179"), dark: UIColor.from("#E57373"))
    static var error300: UIColor
    
    @ColorElement(light: UIColor.from("#F7695F"), dark: UIColor.from("#F7695F"))
    static var error400: UIColor
    
    @ColorElement(light: UIColor.from("#F54337"), dark: UIColor.from("#F54337"))
    static var error500: UIColor
    
    @ColorElement(light: UIColor.from("#DF3D32"), dark: UIColor.from("#EF9A9A"))
    static var error600: UIColor
    
    @ColorElement(light: UIColor.from("#AE3027"), dark: UIColor.from("#AE3027"))
    static var error700: UIColor
    
    @ColorElement(light: UIColor.from("#87251E"), dark: UIColor.from("#87251E"))
    static var error800: UIColor
    
    @ColorElement(light: UIColor.from("#671C17"), dark: UIColor.from("#671C17"))
    static var error900: UIColor
}

// MARK: - Gray Colors
extension Token {
    @ColorElement(light: UIColor.from("FFFFFF"), dark: UIColor.from("1E1E1E"))
    static var gray0: UIColor
    
    @ColorElement(light: UIColor.from("#F0F1F2"), dark: UIColor.from("#2C2C2C"))
    static var gray50: UIColor
    
    @ColorElement(light: UIColor.from("#D1D4D8"), dark: UIColor.from("#383838"))
    static var gray100: UIColor
    
    @ColorElement(light: UIColor.from("#BBBFC5"), dark: UIColor.from("#4D4D4D"))
    static var gray200: UIColor
    
    @ColorElement(light: UIColor.from("#9DA1AA"), dark: UIColor.from("#757575"))
    static var gray300: UIColor
    
    @ColorElement(light: UIColor.from("#898F99"), dark: UIColor.from("#898F99"))
    static var gray400: UIColor
    
    @ColorElement(light: UIColor.from("#6C7380"), dark: UIColor.from("#A0A0A0"))
    static var gray500: UIColor
    
    @ColorElement(light: UIColor.from("#626974"), dark: UIColor.from("#626974"))
    static var gray600: UIColor
    
    @ColorElement(light: UIColor.from("#4D525B"), dark: UIColor.from("#4D525B"))
    static var gray700: UIColor
    
    @ColorElement(light: UIColor.from("#3B3F46"), dark: UIColor.from("#3B3F46"))
    static var gray800: UIColor
    
    @ColorElement(light: UIColor.from("#2D3036"), dark: UIColor.from("#2D3036"))
    static var gray900: UIColor
    
    @ColorElement(light: UIColor.from("161616"), dark: UIColor.from("EFEFEF"))
    static var gray1000: UIColor
}

// MARK: - Transparent
extension Token {
    @ColorElement(color: UIColor.clear)
    static var transparent: UIColor
}

// MARK: - Additional
extension Token {
    @ColorElement(light: UIColor.from("FF6A3B"), dark: UIColor.from("FF8A65"))
    static var bestSeller: UIColor
}
