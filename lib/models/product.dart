class Product {
  const Product({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.preco,
    required this.stock,
    this.codigoBarras,
    this.ultimaAtualizacao,
  });

  final String id;
  final String nome;
  final String categoria;
  final double preco;
  final int stock;
  final String? codigoBarras;
  final DateTime? ultimaAtualizacao;

  Product copyWith({
    String? id,
    String? nome,
    String? categoria,
    double? preco,
    int? stock,
    String? codigoBarras,
    DateTime? ultimaAtualizacao,
    bool clearCodigoBarras = false,
  }) {
    return Product(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      preco: preco ?? this.preco,
      stock: stock ?? this.stock,
      codigoBarras:
          clearCodigoBarras ? null : (codigoBarras ?? this.codigoBarras),
      ultimaAtualizacao: ultimaAtualizacao ?? this.ultimaAtualizacao,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'categoria': categoria,
      'preco': preco,
      'stock': stock,
      'codigoBarras': codigoBarras,
      'ultimaAtualizacao': ultimaAtualizacao?.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      nome: json['nome'] as String,
      categoria: json['categoria'] as String,
      preco: (json['preco'] as num).toDouble(),
      stock: json['stock'] as int,
      codigoBarras: json['codigoBarras'] as String?,
      ultimaAtualizacao: json['ultimaAtualizacao'] == null
          ? null
          : DateTime.parse(json['ultimaAtualizacao'] as String),
    );
  }
}

