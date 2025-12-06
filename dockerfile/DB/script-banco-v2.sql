-- =====================================================
-- Banco de dados Synkro
-- =====================================================
DROP DATABASE IF EXISTS synkro;
CREATE DATABASE synkro;
USE synkro;


-- =====================================================
-- FUNCIONÁRIO E EMPRESA
-- =====================================================
CREATE TABLE status_acesso (
    id TINYINT NOT NULL,
    descricao VARCHAR(50) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE status_operacao (
    id TINYINT NOT NULL,
    descricao VARCHAR(50) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE perfil_ativo (
    id TINYINT NOT NULL,
    descricao VARCHAR(50) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE cargo (
  id INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100),
  PRIMARY KEY (id)
);

CREATE TABLE empresa (
  id INT NOT NULL AUTO_INCREMENT,
  nomeEmpresarial VARCHAR(100),
  ispb VARCHAR(8),
  email VARCHAR(100),
  nomeRepresentante VARCHAR(100),
  statusOperacao TINYINT NOT NULL,
  statusAcesso TINYINT DEFAULT 1,
  PRIMARY KEY (id),
  CONSTRAINT fk_empresa_statusAcesso FOREIGN KEY (statusAcesso) REFERENCES status_acesso(id),
  CONSTRAINT fk_empresa_statusOperacao FOREIGN KEY (statusOperacao) REFERENCES status_operacao(id)
);

CREATE TABLE funcionario(
  id INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(45),
  email VARCHAR(45),
  cpf CHAR(14),
  dtnascimento DATE,
  senha VARCHAR(255),
  fkPerfilAtivo TINYINT NOT NULL,
  fkCargo INT NOT NULL,
  fkEmpresa INT NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_funcionario_cargo FOREIGN KEY (fkCargo) REFERENCES cargo(id),
  CONSTRAINT fk_funcionarios_empresa FOREIGN KEY (fkEmpresa) REFERENCES empresa(id),
  CONSTRAINT fk_funcionario_perfilAtivo FOREIGN KEY (fkPerfilAtivo) REFERENCES perfil_ativo(id)
);

-- =====================================================
-- MAINFRAMES
-- =====================================================
CREATE TABLE setor (
  id INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(45),
  localizacao VARCHAR(45),
  fkEmpresa INT NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_setor_empresa FOREIGN KEY (fkEmpresa) REFERENCES empresa(id)
);

CREATE TABLE sistema_operacional (
  id INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100),
  PRIMARY KEY (id)
);

CREATE TABLE mainframe (
  id INT NOT NULL AUTO_INCREMENT,
  fabricante VARCHAR(100),
  modelo VARCHAR(100),
  macAdress VARCHAR(100) UNIQUE,
  fkSetor INT NOT NULL,
  fkSistemaOperacional INT NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_mainframe_setor FOREIGN KEY (fkSetor) REFERENCES setor(id),
  CONSTRAINT fk_mainframe_sistema_operacional FOREIGN KEY (fkSistemaOperacional) REFERENCES sistema_operacional(id)
);

-- =====================================================
-- MÉTRICAS E COMPONENTES
-- =====================================================
CREATE TABLE tipo(
  id INT NOT NULL AUTO_INCREMENT,
  descricao VARCHAR(100),
  PRIMARY KEY (id)
);

CREATE TABLE componente (
  id INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100),
  PRIMARY KEY (id)
);

CREATE TABLE metrica (
  id INT NOT NULL,
  fkTipo INT NOT NULL,
  fkComponente INT NOT NULL,
  fkMainframe INT NOT NULL,
  min DECIMAL(6,2),
  max DECIMAL(6,2),
  PRIMARY KEY (id, fkTipo, fkComponente, fkMainframe),
  CONSTRAINT fk_metrica_tipo FOREIGN KEY (fkTipo) REFERENCES tipo(id),
  CONSTRAINT fk_metrica_componente FOREIGN KEY (fkComponente) REFERENCES componente(id),
  CONSTRAINT fk_metrica_mainframe FOREIGN KEY (fkMainframe) REFERENCES mainframe(id)
);

-- =====================================================
-- ALERTAS, GRAVIDADE E STATUS
-- =====================================================

CREATE TABLE gravidade (
  id INT NOT NULL AUTO_INCREMENT,
  descricao VARCHAR(100),
  PRIMARY KEY (id)
);

CREATE TABLE status (
  id INT NOT NULL AUTO_INCREMENT,
  descricao VARCHAR(100),
  PRIMARY KEY (id)
);

-- ALERTAS, GRAVIDADE E STATUS
CREATE TABLE alerta (
   id INT NOT NULL AUTO_INCREMENT,
   dt_hora DATETIME,
   valor_coletado DECIMAL(6,2),
   fkGravidade INT NOT NULL,
   fkMetrica INT NOT NULL,
   fkTipo INT NOT NULL,
   fkComponente INT NOT NULL,
   fkMainframe INT NOT NULL,
   fkStatus INT NOT NULL DEFAULT 1,
   PRIMARY KEY (id),
   CONSTRAINT fk_alerta_gravidade FOREIGN KEY (fkGravidade) REFERENCES gravidade(id),
   CONSTRAINT fk_alerta_metrica FOREIGN KEY (fkMetrica, fkTipo, fkComponente, fkMainframe)
       REFERENCES metrica(id, fkTipo, fkComponente, fkMainframe),
   CONSTRAINT fk_alerta_status FOREIGN KEY (fkStatus) REFERENCES status(id)
);

-- Acesso
INSERT INTO status_acesso (id, descricao) VALUES
(1, 'Pendente'),
(2, 'Reprovado'),
(3, 'Aprovado');

-- Operação
INSERT INTO status_operacao (id, descricao) VALUES
(1, 'em-operacao'),
(2, 'liquidado-extrajudicialmente'),
(3, 'liquidacao-ordinaria');

-- Perfil ativo
INSERT INTO perfil_ativo (id, descricao) VALUES
(1, 'Ativo'),
(2, 'Inativo');

-- Cargo
INSERT INTO cargo (nome) VALUES
('Gerente'),
('Analista');


-- Tipo
INSERT INTO tipo (descricao) VALUES 
('Uso'),
('Temperatura'),
('IO Wait'),
('Throughput'),
('IOPS'),
('Read'),
('Write'),
('Latência');

-- Componentes
INSERT INTO componente (nome) VALUES
('Processador'),
('Memória RAM'),
('Disco Rígido');

-- Gravidades
INSERT INTO gravidade (descricao) VALUES 
('Emergência'),
('Muito Urgente'),
('Urgente'),
('Normal');

-- Status
INSERT INTO status (descricao) VALUES 
('Aberto'),
('Em andamento'),
('Resolvido');

-- =====================================================
-- TRIGGER PARA CRIAR GERENTE AUTOMATICAMENTE
-- =====================================================
DELIMITER $$ 
CREATE TRIGGER criarPerfilAoLiberarAcessoEmpresa AFTER UPDATE ON empresa
FOR EACH ROW
BEGIN
  DECLARE idCargoGerente INT;
  
  SELECT id INTO idCargoGerente FROM cargo WHERE nome = 'Gerente' LIMIT 1;
  
  IF NEW.statusAcesso = 3 AND OLD.statusAcesso <> 3 AND
     ((SELECT COUNT(*) FROM funcionario WHERE fkCargo = idCargoGerente AND fkEmpresa = NEW.id) < 1) THEN
     
     INSERT INTO funcionario (nome, email, cpf, dtnascimento, senha, fkPerfilAtivo, fkCargo, fkEmpresa)
     VALUES (
       NEW.nomeRepresentante,
       CONCAT(REPLACE(LOWER(NEW.nomeRepresentante), ' ', '_'), '@gmail.com'),
       '000.000.000-00',
       CURDATE(),
       SHA2('senha123', 256),
       1,
       idCargoGerente,
       NEW.id
     );
     
  ELSEIF NEW.statusAcesso = 2 AND OLD.statusAcesso <> 2 THEN
     UPDATE funcionario SET fkPerfilAtivo = 2 WHERE fkEmpresa = NEW.id;
  ELSE
     UPDATE funcionario SET fkPerfilAtivo = 1 WHERE fkEmpresa = NEW.id;
  END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER DE GRAVIDADE
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_definir_gravidade_auto
BEFORE INSERT ON alerta
FOR EACH ROW
BEGIN
    DECLARE vMin DECIMAL(5,2);
    DECLARE vMax DECIMAL(5,2);
    DECLARE urgente_max DECIMAL(5,2);
    DECLARE limite_max DECIMAL(5,2);
    DECLARE urgente_min DECIMAL(5,2);
    DECLARE limite_min DECIMAL(5,2);

    SELECT min, max INTO vMin, vMax
    FROM metrica
    WHERE id = NEW.fkMetrica;

    -- Limiares Acima do Máximo (MAX side)
    SET limite_max = (vMax + 100) / 2;
    SET urgente_max = vMax; 

    -- Limiares Abaixo do Mínimo (MIN side)
    SET limite_min = (vMin + 0) / 2;
    SET urgente_min = vMin;

    -- 1. EMERGÊNCIA (fkGravidade = 1) - Extremos 100% ou 0%
    IF NEW.valor_coletado = 100.00 OR NEW.valor_coletado = 0.00 THEN
        SET NEW.fkGravidade = 1;

    -- 2. MUITO URGENTE (fkGravidade = 2) - Entre o limite max/min e o extremo
    ELSEIF (NEW.valor_coletado >= limite_max AND NEW.valor_coletado < 100.00)
        OR (NEW.valor_coletado > 0.00 AND NEW.valor_coletado <= limite_min) THEN
        SET NEW.fkGravidade = 2;

    -- 3. URGENTE (fkGravidade = 3) - Entre o limiar VMAX/VMIN e o limite max/min
    ELSEIF (NEW.valor_coletado > urgente_max AND NEW.valor_coletado < limite_max)
        OR (NEW.valor_coletado > limite_min AND NEW.valor_coletado < urgente_min) THEN
        SET NEW.fkGravidade = 3;

    -- 4. NORMAL (fkGravidade = 4) - Dentro do range VMIN e VMAX
    ELSE
        SET NEW.fkGravidade = 4;
    END IF;
END$$
DELIMITER ;
