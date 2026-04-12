import Foundation

enum PhotoCategory: String, CaseIterable, Identifiable {
    case all          = "All"
    case people       = "People"
    case scenery      = "Scenery"
    case food         = "Food"
    case architecture = "Architecture"
    case animals      = "Animals"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .all:          return "photo.stack"
        case .people:       return "person.2.fill"
        case .scenery:      return "mountain.2"
        case .food:         return "fork.knife"
        case .architecture: return "building.2.fill"
        case .animals:      return "pawprint.fill"
        }
    }

    /// Exact Vision framework label identifiers (snake_case) for this category.
    /// Matched against VNClassificationObservation.identifier using equality.
    /// Empty for categories resolved via Photos smart albums.
    var visionLabels: [String] {
        switch self {

        case .people:
            return [
                "people", "adult", "baby", "child", "teen", "crowd",
                "bride", "groom", "bridesmaid",
                "entertainer", "singer", "ballet_dancer",
                "ballet", "cheerleading", "deejay", "performance",
                "graduation", "ceremony",
            ]

        case .scenery:
            return [
                // Sky & atmosphere
                "blue_sky", "night_sky", "rainbow", "aurora", "sunset_sunrise",
                "haze", "storm", "thunderstorm", "lightning", "cloudy",
                // Water
                "ocean", "lake", "river", "waterfall", "water_body",
                "wetland", "glacier", "iceberg", "creek", "waterways",
                // Land & terrain
                "mountain", "hill", "cliff", "canyon", "desert", "sand_dune",
                "volcano", "cave", "island", "shore", "beach",
                "rocks", "sand", "lava",
                // Vegetation
                "forest", "jungle", "grass", "foliage", "vegetation",
                "orchard", "vineyard", "mangrove", "rice_field",
                // Snow & ice
                "snow", "blizzard",
                // Paths & outdoor
                "trail", "land",
            ]

        case .food:
            return [
                // Broad category labels Vision uses for all food
                "food", "dessert", "drink", "fruit", "vegetable",
                "meat", "seafood", "baked_goods", "pastry",
                // Prepared dishes
                "pizza", "sushi", "hamburger", "sandwich", "salad",
                "pasta", "soup", "steak", "curry", "ramen", "taco",
                "burrito", "gyoza", "dumpling", "kebab", "shawarma",
                "biryani", "paella", "risotto", "stir_fry", "fried_chicken",
                "grilled_chicken", "rotisserie", "springroll", "samosa",
                "falafel", "bruschetta", "pierogi", "nachos", "quesadilla",
                "wonton", "satay", "souvlaki", "tapas", "tabbouleh",
                "tempura", "teriyaki", "antipasti",
                "fries", "hotdog",
                // Bakery & sweets
                "cake", "cupcake", "cake_regular", "donut", "cookie",
                "brownie", "croissant", "bagel", "bread", "muffin",
                "waffle", "pancake", "crepe", "biscuit", "biscotti",
                "baklava", "strudel", "fruitcake", "gingerbread",
                "tiramisu", "cheesecake",
                // Frozen
                "ice_cream", "frozen_dessert", "popsicle",
                // Dairy & eggs
                "cheese", "egg", "fried_egg", "scrambled_eggs", "omelet", "yolk",
                // Proteins
                "bacon", "sausage", "salami", "spareribs", "meatball",
                "pepperoni", "ham", "poultry",
                // Seafood specific
                "salmon", "tuna", "lobster", "crab", "clam",
                "oyster", "mussel", "scallop", "sardine", "anchovy",
                "seabass", "mackerel", "trout", "swordfish", "roe",
                "shellfish_prepared",
                // Fruits
                "apple", "banana", "oranges", "grape", "strawberry",
                "watermelon", "pineapple", "mango", "avocado", "lemon",
                "lime", "cherry", "peach", "pear", "melon", "kiwi",
                "blueberry", "blackberry", "raspberry", "citrus_fruit",
                "grapefruit", "cantaloupe", "honeydew", "nectarine",
                "plum", "apricot", "fig", "guava", "papaya", "lychee",
                "pomegranate", "starfruit", "rambutan", "durian",
                "persimmon", "mangosteen",
                // Vegetables
                "tomato", "broccoli", "carrot", "corn", "potato",
                "onion", "garlic", "lettuce", "spinach", "cucumber",
                "bell_pepper", "pepper_veggie", "eggplant", "mushroom",
                "cauliflower", "artichoke", "asparagus", "zucchini",
                "pea", "green_beans", "beet", "radish", "leek",
                "celery", "arugula", "daikon", "kohlrabi",
                "edamame", "taro",
                // Drinks
                "coffee", "tea_drink", "juice", "smoothie", "soda",
                "beer", "wine", "red_wine", "white_wine", "sparkling_wine",
                "cocktail", "martini", "margarita", "sangria", "mojito",
                "bubble_tea", "milkshake", "tequila",
                // Grains & nuts
                "rice", "wheat", "naan", "pita", "tortilla", "white_bread",
                "matzo", "oatmeal", "grain", "quinoa",
                "almond", "peanut", "cashew", "pistachio", "pecan",
                "macadamia", "chestnut",
                // Condiments & spreads
                "honey", "jelly", "mustard", "condiment",
                "hummus", "guacamole",
                // Spices & herbs
                "spice", "herb", "turmeric", "lemongrass", "cilantro",
                "chives", "rosemary", "sesame", "wasabi", "habanero", "jalapeno",
                // Misc snacks & sweets
                "popcorn", "pretzel", "candy", "lollipop",
                "chocolate", "taffy", "caramel", "marshmallow",
                "pudding", "jello", "flan", "souffle", "fondue",
                "coleslaw", "sauerkraut",
                "tapioca_pearls",
            ]

        case .architecture:
            return [
                // Broad
                "building", "structure",
                // Infrastructure
                "bridge", "tunnel", "dam", "silo", "smokestack",
                "tower", "clock_tower", "belltower", "lighthouse",
                "skyscraper",
                // Historical & landmark
                "castle", "ruins", "megalith",
                "pyramid", "obelisk", "monument", "arch", "dome",
                // Civic & cultural
                "stadium", "arena", "museum", "library", "theater",
                "hangar", "barn", "shed", "greenhouse", "aquarium",
                "airport", "harbour",
                // Commercial
                "restaurant", "storefront",
                // Residential
                "house_single", "apartment", "domicile",
                // Decorative
                "gazebo", "pergola", "fountain",
                // Other structures
                "windmill", "watermill", "wind_turbine",
                "portal", "boathouse",
            ]

        case .animals:
            return [
                // Broad taxonomy
                "animal", "mammal", "bird", "fish", "reptile", "insect",
                "arachnid", "arthropods", "canine", "feline", "cetacean",
                "marsupial", "ungulates", "gastropod", "cephalopod", "mollusk",
                // Common pets & domestic
                "cat", "adult_cat", "kitten", "dog", "horse", "pig", "sheep",
                "goat", "cow", "donkey", "rabbit", "hamster", "gerbil",
                "ferret", "chinchilla",
                // Dog breeds
                "australian_shepherd", "basenji", "basset", "beagle",
                "bernese_mountain", "bichon", "bulldog", "chihuahua",
                "collie", "corgi", "dachshund", "dalmatian", "doberman",
                "german_shepherd", "greyhound", "hound", "husky", "irish_wolfhound",
                "jack_russell_terrier", "malamute", "malinois", "mastiff",
                "newfoundland", "pitbull", "pomeranian", "poodle",
                "retriever", "ridgeback", "rottweiler", "saint_bernard",
                "schnauzer", "setter", "sheepdog", "spaniel", "terrier",
                "vizsla", "weimaraner",
                // Big cats & predators
                "lion", "tiger", "cheetah", "leopard", "cougar", "bobcat",
                "lynx", "bear", "coyote_wolf", "fox", "hyena",
                // Land wildlife
                "elephant", "giraffe", "zebra", "hippopotamus", "rhinoceros",
                "deer", "elk", "moose", "bison", "camel", "llama",
                "kangaroo", "koala", "panda", "squirrel", "raccoon",
                "hedgehog", "porcupine", "skunk", "prairie_dog",
                "rat", "rodent", "boar", "lemur",
                // Reptiles & amphibians
                "snake", "snake_other", "rattlesnake", "python",
                "alligator_crocodile", "lizard", "gecko", "iguana",
                "monitor_lizard", "chameleon", "turtle", "tortoise", "frog", "toad",
                // Birds
                "eagle", "owl", "parrot", "cockatoo", "penguin", "flamingo",
                "peacock", "toucan", "hummingbird", "swan", "pelican",
                "puffin", "raven", "sparrow", "woodpecker", "stork",
                "heron", "gull", "pigeon", "parakeet", "raptor",
                "peregrine", "ostrich", "vulture",
                // Marine life
                "shark", "whale", "dolphin", "seal", "sealion", "walrus",
                "otter", "jellyfish", "seahorse", "starfish", "stingray",
                "puffer_fish", "clownfish", "goldfish", "guppy", "angelfish",
                "sunfish", "barracuda", "snapper", "lionfish", "koi",
                "lobster", "crab", "barnacle", "coral_reef", "urchin",
                // Insects & small creatures
                "butterfly", "bee", "ant", "ladybug", "dragonfly",
                "caterpillar", "centipede", "millipede", "moth",
                "spider", "scorpion", "snail", "worm", "scarab",
            ]

        case .all:
            return []
        }
    }
}
