/// Category-name groups used by the space configuration (0047): cars and
/// pickups share the same spots, motorcycles have their own, and trucks/buses
/// are not limited. Keep these names in sync with the SQL trigger.
const carGroupNames = {'car', 'carro', 'auto', 'camioneta', 'suv'};
const motoGroupNames = {'moto', 'motos', 'motorcycle'};

bool isCarGroup(String categoryName) =>
    carGroupNames.contains(categoryName.toLowerCase());

bool isMotoGroup(String categoryName) =>
    motoGroupNames.contains(categoryName.toLowerCase());
